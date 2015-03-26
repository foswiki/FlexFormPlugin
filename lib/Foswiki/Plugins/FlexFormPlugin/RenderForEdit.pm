# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2015 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::FlexFormPlugin::RenderForEdit;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Form();
use Foswiki::OopsException();
use Error qw( :try );
use Encode ();
use CGI();

use Foswiki::Plugins::FlexFormPlugin::Base();
our @ISA = qw( Foswiki::Plugins::FlexFormPlugin::Base );

sub handle {
  my ($this, $params, $theTopic, $theWeb) = @_;

  #$this->writeDebug("called ".__PACKAGE__."->handle($theTopic, $theWeb)");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $thisRev = $params->{revision};
  my $theFields = $params->{field} || $params->{fields};
  my $theForm = $params->{form};
  my $theValue = $params->{value};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theMap = $params->{map} || '';
  my $theMandatory = $params->{mandatory};
  my $theHidden = $params->{hidden};
  my $theHiddenFormat = $params->{hiddenformat};
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 0);
  my $thePrefix = $params->{prefix};

  my $useMultiLingual = Foswiki::Func::getContext()->{MultiLingualPluginEnabled};

  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {
    $theHeader = '<div class=\'foswikiFormSteps\'>';
    $theFooter = '</div>';
    $theFormat = '<div class=\'foswikiFormStep\'>
      <h3> $title:$mandatory </h3>
      $edit
      $extra
      <div class=\'foswikiFormDescription\'>$description</div>
    </div>';
  } else {
    $theFormat = '$edit$mandatory' unless defined $theFormat;
    $theHeader = '' unless defined $theHeader;
    $theFooter = '' unless defined $theFooter;
  }
  $theMandatory = " <span class='foswikiAlert'>**</span> " unless defined $theMandatory;
  $theHiddenFormat = '$edit' unless defined $theHiddenFormat;

  my $thisWeb = $theWeb;

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = $this->getTopicObject($thisWeb, $thisTopic, $thisRev);

  # give beforeEditHandlers a chance
  # SMELL: watch out for the fix of Item1965; it must be applied here as well; for now
  # we mimic the core behaviour here
  my $text = $topicObj->text();
  $this->{session}{plugins}->dispatch('beforeEditHandler', $text, $thisTopic, $thisWeb, $topicObj);
  $topicObj->text($text);

  $theForm = $this->{session}{request}->param('formtemplate') unless $theForm;
  $theForm = $topicObj->getFormName unless $theForm;
  return '' unless $theForm;

  my $theFormWeb = $thisWeb;
  ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($theFormWeb, $theForm);

  if (!Foswiki::Func::topicExists($theFormWeb, $theForm)) {
    return '';
  }

  my $form;
  try {
    $form = new Foswiki::Form($this->{session}, $theFormWeb, $theForm);
  } catch Foswiki::OopsException with {
    # nop
  };
  return $this->inlineError("can't load form $theFormWeb.$theForm") unless $form;

  my $fieldTitles;
  foreach my $map (split(/\s*,\s*/, $theMap)) {
    $map =~ s/\s*$//;
    $map =~ s/^\s*//;
    if ($map =~ /^(.*)=(.*)$/) {
      $fieldTitles->{$1} = $2;
    }
  }

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      $fieldName =~ s/\s*$//;
      $fieldName =~ s/^\s*//;
      my $field = $form->getField($fieldName);
      $this->writeDebug("WARNING: no field for '$fieldName' in $theFormWeb.$theForm") unless $field;
      push @selectedFields, $field if $field;
    }
  } else {
    @selectedFields = @{$form->getFields()};
  }

  my @result = ();
  foreach my $field (@selectedFields) {
    next unless $field;

    my $fieldExtra = '';
    my $fieldEdit = '';

    my $fieldName = $field->{name};
    my $origFieldName = $field->{name};
    if (defined $thePrefix) {
      $field->{name} = $thePrefix . $fieldName;
    }

    my $fieldType = $field->{type};
    my $fieldSize = $field->{size};
    my $fieldAttrs = $field->{attributes};
    my $fieldDescription = $field->{tooltip} || $field->{description} || '';
    my $fieldTitle = $field->{title};
    my $fieldDefiningTopic = $field->{definingTopic};

    # get the list of all allowed values
    my $fieldAllowedValues = '';
    # CAUTION: don't use field->getOptions() on a +values field as that won't return the full valueMap...only the value part, but not the title map
    if ($field->can('getOptions') && $field->{type} !~ /\+values/) {
      my $options = $field->getOptions();
      if ($options) {
        $fieldAllowedValues = join($theValueSep, @$options);
      }
    } else {
      # fallback to field->value
      my $options = $field->{value};
      if ($options) {
        $fieldAllowedValues = join($theValueSep, split(/\s*,\s*/, $options));
      }
    }

    # get the list of all allowed values without any +values mapping applied
    my $fieldOrigAllowedValues = '';
    if ($field->can('getOptions')) {
      my $options = $field->getOptions();
      if ($options) {
        $fieldOrigAllowedValues = join($theValueSep, @$options);
      }
    } else {
      # fallback to field->value
      my $options = $field->{value};
      if ($options) {
        $fieldOrigAllowedValues = join($theValueSep, split(/\s*,\s*/, $options));
      }
    }

    # get the default value
    my $fieldDefault = '';
    if ($field->can('getDefaultValue')) {
      $fieldDefault = $field->getDefaultValue() || '';
    }

    $fieldSize = $params->{$fieldName . '_size'} if defined $params->{$fieldName . '_size'};
    $fieldAttrs = $params->{$fieldName . '_attributes'} if defined $params->{$fieldName . '_attributes'};
    $fieldDescription = $params->{$fieldName . '_tooltip'} if defined $params->{$fieldName . '_tooltip'};
    $fieldDescription = $params->{$fieldName . '_description'} if defined $params->{$fieldName . '_description'};
    $fieldTitle = $params->{$fieldName . '_title'} if defined $params->{$fieldName . '_title'};    # see also map
    $fieldAllowedValues = $params->{$fieldName . '_values'} if defined $params->{$fieldName . '_values'};
    $fieldDefault = $params->{$fieldName . '_default'} if defined $params->{$fieldName . '_default'};
    $fieldType = $params->{$fieldName . '_type'} if defined $params->{$fieldName . '_type'};

    my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName . '_sort'}, $theSort);
    $fieldAllowedValues = $this->sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

    my $fieldFormat = $params->{$fieldName . '_format'} || $theFormat;

    # temporarily remap field to another type
    my $fieldClone;
    if ( defined($params->{$fieldName . '_type'})
      || defined($params->{$fieldName . '_size'})
      || defined($params->{$fieldName . '_name'})
      || $fieldSort)
    {
      $fieldClone = $form->createField(
        $fieldType,
        name => $params->{$fieldName . '_name'} || $fieldName,
        title => $fieldTitle,
        size => $fieldSize,
        value => $fieldAllowedValues,
        description => $fieldDescription,
        tooltip => $fieldDescription,
        attributes => $fieldAttrs,
        definingTopic => $fieldDefiningTopic,
        web => $topicObj->web,
        topic => $topicObj->topic,
      );
      $field = $fieldClone;
    }
    $this->translateField($field, $theForm, $theWeb);

    #$this->writeDebug("reading fieldName=$fieldName");

    my $fieldValue;
    if (defined $theValue) {
      $fieldValue = $theValue;
    } else {
      $fieldValue = $params->{$fieldName . '_value'};
    }

    unless (defined $fieldValue) {
      my $query = Foswiki::Func::getCgiQuery();
      $fieldValue = $query->param($fieldName);
    }

    unless (defined $fieldValue) {
      my $metaField = $topicObj->get('FIELD', $fieldName);
      unless ($metaField) {
        # Not a valid field name, maybe it's a title.
        $fieldName = Foswiki::Form::fieldTitle2FieldName($fieldName);
        $metaField = $topicObj->get('FIELD', $fieldName);
      }
      $fieldValue = $metaField->{value} if $metaField;
    }

    $fieldValue = $fieldDefault unless defined $fieldValue && $fieldValue ne '';

    next if $theInclude && $fieldName !~ /$theInclude/;
    next if $theExclude && $fieldName =~ /$theExclude/;
    next if $theIncludeAttr && $fieldAttrs !~ /$theIncludeAttr/;
    next if $theExcludeAttr && $fieldAttrs =~ /$theExcludeAttr/;

    unless (defined $fieldValue) {
      $fieldValue = "\0";    # prevent dropped value attr in CGI.pm
    }

    $fieldEdit = $this->{session}{plugins}->dispatch('renderFormFieldForEditHandler', $fieldName, $fieldType, $fieldSize, $fieldValue, $fieldAttrs, $fieldAllowedValues);

    my $isHidden = ($theHidden && $fieldName =~ /^($theHidden)$/) ? 1 : 0;
    unless ($fieldEdit) {
      if ($isHidden) {
        # sneak in the value into the topicObj
        my $metaField = $topicObj->get('FIELD', $fieldName);
        if ($metaField) {
          $metaField->{value} = $fieldValue;
        } else {
          # temporarily add metaField for rendering it as hidden field
          $metaField = {
            name => $fieldName,
            title => $fieldName,
            value => $fieldValue
          };
          $topicObj->putKeyed('FIELD', $metaField);
        }
        $fieldEdit = $field->renderHidden($topicObj);
      } else {
        if ($Foswiki::Plugins::VERSION > 2.0) {
          ($fieldExtra, $fieldEdit) = $field->renderForEdit($topicObj, $fieldValue);
        } else {
          # pre-TOM
          ($fieldExtra, $fieldEdit) = $field->renderForEdit($thisWeb, $thisTopic, $fieldValue);
        }
      }
    }

    $fieldEdit =~ s/\0//g;
    $fieldValue =~ s/\0//g;

    # escape %VARIABLES inside input values
    $fieldEdit =~ s/(<input.*?value=["'])(.*?)(["'])/
      my $pre = $1;
      my $tmp = $2;
      my $post = $3;
      $tmp =~ s#%#%<nop>#g;
      $pre.$tmp.$post;
    /ge;

    # escape %VARIABLES inside textareas
    $fieldEdit =~ s/(<textarea.*?>)(.*?)(<\/textarea>)/
      my $pre = $1;
      my $tmp = $2;
      my $post = $3;
      $tmp =~ s#%#%<nop>#g;
      $pre.$tmp.$post;
    /ges;

    my $line = $isHidden ? $theHiddenFormat : $fieldFormat;
    $fieldTitle = $fieldTitles->{$fieldName} if $fieldTitles && $fieldTitles->{$fieldName};
    my $fieldMandatory = '';
    $fieldMandatory = $theMandatory if $field->isMandatory();

    $fieldTitle = $this->translate($fieldTitle, $theFormWeb, $theForm);

    $line =~ s/\$mandatory/$fieldMandatory/g;
    $line =~ s/\$edit\b/$fieldEdit/g;
    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;
    $line =~ s/\$(orig)?value\b/$fieldValue/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$tooltip\b/$fieldDescription/g;
    $line =~ s/\$description\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$extra\b/$fieldExtra/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
    $field->{name} = $origFieldName if defined $origFieldName;
  }

  my $result = $theHeader . join($theSep, @result) . $theFooter;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  #print STDERR "result=$result\n";

  return '<literal><noautolink>' . $result . '</noautolink></literal>';
}

1;
