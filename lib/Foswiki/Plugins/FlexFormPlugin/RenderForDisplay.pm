# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2020 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexFormPlugin::RenderForDisplay;

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

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $thisRev = $params->{revision} || $params->{rev};
  my $theFields = $params->{field} || $params->{fields};
  my $theForm = $params->{form};
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
  my $theLabelFormat = $params->{labelformat} || '';
  my $theAutolink = Foswiki::Func::isTrue($params->{autolink}, 1);
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 0);
  my $theHideEmpty = Foswiki::Func::isTrue($params->{hideempty}, 0);

  $theExcludeAttr = '\bh\b' unless defined $theExcludeAttr;

  # get defaults from template
  my $theType = $params->{type} || '';
  $theType = 'div' if !Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid';
  $theType = 'table' unless $theType =~ /^(div|table|grid)$/;

  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {

    # table
    if ($theType eq '' || $theType eq 'table') { 
      $theHeader = '<div class=\'foswikiFormSteps\'><table class=\'foswikiLayoutTable\'>';
      $theFooter = '</table></div>';
      $theFormat = '<tr>
        <th class="foswikiTableFirstCol"> $title: </th>
        <td class="foswikiFormValue"> 
$value
<!-- -->
        </td>
      </tr>'
    } 

    # div
    elsif ($theType eq 'div') { 
      $theHeader = '<div class=\'foswikiFormSteps\'>';
      $theFooter = '</div>';
      $theFormat = '<div class=\'foswikiFormStep\'>
        <h3> $title </h3>
$value
<!-- -->
      </div>';
    } 

    # grid
    elsif (Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid') {
      $theHeader = '<div class=\'foswikiPageForm foswikiGridForm\'>%BEGINGRID{gutter="1"}%';
      $theFooter = '%ENDGRID%</div>';
      $theFormat = '%BEGINCOL{"3" class="foswikiGridHeader"}% <h3 >$title:</h3>
        %BEGINCOL{"9"}%
$value$n';
    }
  }

  $theHeader ||= '';
  $theFooter ||= '';
  $theFormat ||= '';

  # make it compatible
  $theHeader =~ s/%A_TITLE%/\$title/g;
  $theFormat =~ s/%A_TITLE%/\$title/g;
  $theFormat =~ s/%A_VALUE%/\$value/g;
  $theFooter =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_VALUE%/\$value/g;

  my $thisWeb = $theWeb;
  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = $this->getTopicObject($thisWeb, $thisTopic, $thisRev);

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

  my $formTitle;
  if ($form->can('getPath')) {
    $formTitle = $form->getPath;
  } else {
    $formTitle = $form->{web} . '.' . $form->{topic};
  }
  $formTitle =~ s/\//./g;    # normalize web names

  $theHeader =~ s/\$title/$formTitle/g;
  $theFooter =~ s/\$title/$formTitle/g;

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

    my $fieldName = $field->{name};
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

    my $metaField = $topicObj->get('FIELD', $fieldName);
    unless ($metaField) {
      # Not a valid field name, maybe it's a title.
      $fieldName = Foswiki::Form::fieldTitle2FieldName($fieldName);
      $metaField = $topicObj->get('FIELD', $fieldName);
    }
    my $fieldValue = $metaField ? $metaField->{value} : undef;

    $fieldSize = $params->{$fieldName . '_size'} if defined $params->{$fieldName . '_size'};
    $fieldAttrs = $params->{$fieldName . '_attributes'} if defined $params->{$fieldName . '_attributes'};
    $fieldDescription = $params->{$fieldName . '_tooltip'} if defined $params->{$fieldName . '_tooltip'};
    $fieldDescription = $params->{$fieldName . '_description'} if defined $params->{$fieldName . '_description'};
    $fieldTitle = $params->{$fieldName . '_title'} if defined $params->{$fieldName . '_title'};    # see also map
    $fieldAllowedValues = $params->{$fieldName . '_values'} if defined $params->{$fieldName . '_values'};
    $fieldDefault = $params->{$fieldName . '_default'} if defined $params->{$fieldName . '_default'};
    $fieldType = $params->{$fieldName . '_type'} if defined $params->{$fieldName . '_type'};
    $fieldValue = $params->{$fieldName . '_value'} if defined $params->{$fieldName . '_value'};

    my $fieldAutolink = Foswiki::Func::isTrue($params->{$fieldName . '_autolink'}, $theAutolink);

    my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName . '_sort'}, $theSort);
    $fieldAllowedValues = $this->sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

    my $fieldFormat = $params->{$fieldName . '_format'} || $theFormat;

    # temporarily remap field to another type
    my $fieldClone;
    if ( defined($params->{$fieldName . '_type'})
      || defined($params->{$fieldName . '_size'})
      || $fieldSort)
    {
      $fieldClone = $form->createField(
        $fieldType,
        name => $fieldName,
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

    $fieldValue = $fieldDefault unless defined $fieldValue && $fieldValue ne '';
    next if $theHideEmpty && (!defined($fieldValue) || $fieldValue eq '');
    next if $theInclude && $fieldName !~ /$theInclude/;
    next if $theExclude && $fieldName =~ /$theExclude/;
    next if $theIncludeAttr && $fieldAttrs !~ /$theIncludeAttr/;
    next if $theExcludeAttr && $fieldAttrs =~ /$theExcludeAttr/;

    my $line = $fieldFormat;
    unless ($fieldName) {    # label
      next unless $theLabelFormat;
      $line = $theLabelFormat;
    }
    $line = '<noautolink>' . $line . '</noautolink>' unless $fieldAutolink;

    $fieldTitle = $fieldTitles->{$fieldName} if $fieldTitles && $fieldTitles->{$fieldName};

    # clean up
    $fieldTitle =~ s/^\[\[([^]]+)\]\]$/$1/g;

    $fieldTitle = $this->translate($fieldTitle, $theFormWeb, $theForm);

    # some must be expanded before renderForDisplay
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;

    # For Foswiki > 1.2, treat $value ourselves to get a consistent
    # behavior across all releases:
    # - patch in (display) value as $value
    # - use raw value as $origvalue
    my $origValue = $fieldValue;

    $this->translateField($field, $theWeb, $theForm);

    # now dive into the core and see what we get out of it
    my $displayValue;
    if ($field->can("getDisplayValue")) {
      $displayValue = $field->getDisplayValue($fieldValue, $thisWeb, $thisTopic);
    } else {
      $displayValue = $field->renderForDisplay('$value(display)', $fieldValue);
    }

    next if $theHideEmpty && (!defined($displayValue) || $displayValue eq '');

    # render this by ourselfs
    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$(tooltip|description)\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$form\b/$formTitle/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$value(\(display\))?\b/$displayValue/g;
    $line =~ s/\$origvalue\b/$origValue/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
  }

  return '' if $theHideEmpty && !@result;

  my $result = $theHeader . join($theSep, @result) . $theFooter;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  return $result;
}

1;

