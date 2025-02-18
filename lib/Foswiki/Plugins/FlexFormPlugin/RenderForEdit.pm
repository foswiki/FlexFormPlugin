# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2025 Michael Daum http://michaeldaumconsulting.com
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

use Foswiki::Plugins::FlexFormPlugin::Base();
our @ISA = qw( Foswiki::Plugins::FlexFormPlugin::Base );

sub handle {
  my ($this, $params, $theTopic, $theWeb) = @_;

  #$this->writeDebug("called ".__PACKAGE__."->handle($theTopic, $theWeb)");

  my $request = Foswiki::Func::getRequestObject();
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $thisRev = $params->{revision} // $params->{rev} // $request->param("rev");
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
  my $theHideEmpty = Foswiki::Func::isTrue($params->{hideempty}, 0);
  my $theIgnoreError = Foswiki::Func::isTrue($params->{ignoreerror}, 0);
  my %typeMapping = ();
  
  foreach my $item (split(/\s*,\s*/, $params->{typemapping} || '')) {
    if ($item =~ /^(.*)=(.*)$/) {
      $typeMapping{$1} = $2;
    }
  }

  # get defaults from template
  my $theType = $params->{type} || '';
  $theType = 'div' if !Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid';
  $theType = 'div' unless $theType =~ /^(div|table|grid)$/;

  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {

    # div
    if ($theType eq '' || $theType eq 'div') { 
      $theHeader = '<div class=\'foswikiFormSteps foswikiEditForm\'>';
      $theFooter = '</div>';
      $theFormat = '<div class=\'foswikiFormStep\'>
        <h3> $title:$mandatory </h3>
        $edit
        $extra
        <div class=\'foswikiFormDescription\'>$description</div>
      </div>';
    } 

    # table
    elsif ($theType eq 'table') {
      $theHeader = '<div class=\'foswikiPageForm foswikiTableEditForm\'><table class=\'foswikiLayoutTable\'>';
      $theFooter = '</table></div>';
      $theFormat = '<tr><th> $title:$mandatory </th>
        <td>
        $edit
        $extra
        <div class=\'foswikiFormDescription\'>$description</div>
        </td></tr>';
    } 

    # grid
    elsif (Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid') {
      $theHeader = '<div class=\'foswikiPageForm foswikiGridForm\'>%BEGINGRID{gutter="1"}%';
      $theFooter = '%ENDGRID%</div>';
      $theFormat = '%BEGINCOL{"3" class="foswikiGridHeader"}% <h3 >$title:$mandatory</h3>
        %BEGINCOL{"9"}%
        $edit
        $extra
        <div class=\'foswikiFormDescription\'>$description</div>';
    }
  } else {
    $theFormat = '$edit$mandatory' unless defined $theFormat;
    $theHeader = '' unless defined $theHeader;
    $theFooter = '' unless defined $theFooter;
  }
  $theMandatory = "<span class='foswikiAlert'>**</span> " unless defined $theMandatory;
  $theHiddenFormat = '$edit' unless defined $theHiddenFormat;

  my $thisWeb = $params->{web} || $theWeb;

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = $this->getTopicObject($thisWeb, $thisTopic, $thisRev);

  # give beforeEditHandlers a chance
  # SMELL: watch out for the fix of Item1965; it must be applied here as well; for now
  # we mimic the core behaviour here
  my $text = $topicObj->text();
  $this->{session}{plugins}->dispatch('beforeEditHandler', $text, $thisTopic, $thisWeb, $topicObj);
  $topicObj->text($text);

  $theForm = $request->param('formtemplate') unless $theForm;
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
  return ($theIgnoreError?"":$this->inlineError("can't load form $theFormWeb.$theForm")) unless $form;

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
    my $fields = $form->getFields();
    @selectedFields = @$fields if defined $fields;
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
    if ($field->can('getOptions') && $field->{type} !~ /(\+values|topic|user)/) {
      my $options = $field->getOptions($thisWeb, $thisTopic);
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
      my $options = $field->getOptions($thisWeb, $thisTopic);
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
      $fieldDefault = $field->getDefaultValue($thisWeb, $thisTopic) || '';
    }

    $fieldSize = $params->{$fieldName . '_size'} if $params->{$fieldName . '_size'} && $params->{$fieldName . '_size'} ne "";
    $fieldType = $params->{$fieldName . '_type'} if $params->{$fieldName . '_type'} && $params->{$fieldName . '_type'} ne "";
    $fieldType = $typeMapping{$fieldType} if defined $typeMapping{$fieldType};

    $fieldAttrs = $params->{$fieldName . '_attributes'} if defined $params->{$fieldName . '_attributes'};
    $fieldDescription = $params->{$fieldName . '_tooltip'} if defined $params->{$fieldName . '_tooltip'};
    $fieldDescription = $params->{$fieldName . '_description'} if defined $params->{$fieldName . '_description'};
    $fieldTitle = $params->{$fieldName . '_title'} if defined $params->{$fieldName . '_title'};    # see also map
    $fieldAllowedValues = $params->{$fieldName . '_values'} if defined $params->{$fieldName . '_values'};
    $fieldAllowedValues = $params->{$fieldName . '_params'} if defined $params->{$fieldName . '_params'};
    $fieldDefault = $params->{$fieldName . '_default'} if defined $params->{$fieldName . '_default'};
    $fieldDefiningTopic = $params->{$fieldName . '_definition'} if defined $params->{$fieldName . '_definition'};

    my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName . '_sort'}, $theSort);
    $fieldAllowedValues = $this->sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

    my $fieldFormat = $params->{$fieldName . '_format'} || $theFormat;
    # temporarily remap field to another type
    my $fieldClone;
    if ( $fieldType ne $field->{type}
      || $params->{$fieldName . '_size'}
      || defined($params->{$fieldName . '_definition'})
      || defined($params->{$fieldName . '_name'})
      || defined($params->{$fieldName . '_values'})
      || defined($params->{$fieldName . '_params'})
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
        web => $thisWeb,
        topic => $thisTopic,
      );
      $field = $fieldClone;
    }
    $this->translateField($field, $thisWeb, $theForm);

    #$this->writeDebug("reading fieldName=$fieldName");

    my $fieldValue;
    if (defined $theValue) {
      $fieldValue = $theValue;
    } else {
      $fieldValue = $params->{$fieldName . '_value'};
    }

    unless (defined $fieldValue) {
      my $query = Foswiki::Func::getCgiQuery();
      if (defined $query->param($fieldName)) {
        $fieldValue = join(", ", grep {!/^$/} $query->multi_param($fieldName));
        #print STDERR "fieldValue=$fieldValue\n";
      }
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

    my $fieldMandatory = '';
    my $origFieldAttributes;
    if (!$field->isMandatory() && Foswiki::Func::isTrue($params->{$fieldName . '_mandatory'}, 0)) {
      $origFieldAttributes = $field->{attributes};
      $field->{attributes} .= 'M';
    }
    $fieldMandatory = $theMandatory if $field->isMandatory();

    $fieldEdit = $this->{session}{plugins}->dispatch('renderFormFieldForEditHandler', $fieldName, $fieldType, $fieldSize, $fieldValue, $fieldAttrs, $fieldAllowedValues);

    my $isHidden = ($fieldAttrs=~ /h/i || $theHidden && $fieldName =~ /^($theHidden)$/) ? 1 : 0;
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

    # clean up
    $fieldTitle =~ s/^\[\[([^]]+)\]\]$/$1/g;

    $fieldTitle = $this->translate($fieldTitle, $theFormWeb, $theForm);
    $fieldDescription = $this->translate($fieldDescription, $theFormWeb, $theForm);

    $line =~ s/\$mandatory/$fieldMandatory/g;
    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$tooltip\b/$fieldDescription/g;
    $line =~ s/\$description\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$extra\b/$fieldExtra/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;
    $line =~ s/\$(orig)?value\b/$fieldValue/g;
    $line =~ s/\$edit\b/$fieldEdit/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
    $field->{name} = $origFieldName if defined $origFieldName;
    $field->{attributes} = $origFieldAttributes if defined $origFieldAttributes;
  }

  return '' if $theHideEmpty && !@result;

  my $result = $theHeader . join($theSep, @result) . $theFooter;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  #print STDERR "result=$result\n";

  return '<literal><noautolink>' . $result . '</noautolink></literal>';
}

1;
