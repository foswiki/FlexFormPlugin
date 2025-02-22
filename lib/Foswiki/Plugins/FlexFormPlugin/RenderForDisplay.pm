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

package Foswiki::Plugins::FlexFormPlugin::RenderForDisplay;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Form();
use Foswiki::OopsException();
use Error qw( :try );
use Foswiki::Plugins::JQueryPlugin ();

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
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theIncludeValue = $params->{includevalue};
  my $theExcludeValue = $params->{excludevalue};
  my $theMap = $params->{map} || '';
  my $theLabelFormat = $params->{labelformat} || '';
  my $theAutolink = Foswiki::Func::isTrue($params->{autolink}, 1);
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 0);
  my $theHideEmpty = Foswiki::Func::isTrue($params->{hideempty}, 0);
  my $theIgnoreError = Foswiki::Func::isTrue($params->{ignoreerror}, 0);
  my $theEditIcon = $params->{editicon} // 'fa-pencil';
  my %typeMapping = ();
  my $theReload = $params->{reload} // '';

  foreach my $item (split(/\s*,\s*/, $params->{typemapping} || '')) {
    if ($item =~ /^(.*)=(.*)$/) {
      $typeMapping{$1} = $2;
    }
  }

  $theExcludeAttr = '\bh\b' unless defined $theExcludeAttr;

  # get topic and form
  my $thisWeb = $params->{web} || $theWeb;
  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = $this->getTopicObject($thisWeb, $thisTopic, $thisRev);

  my $context = Foswiki::Func::getContext();
  my $theEditable = Foswiki::Func::isTrue($params->{editable}, 0);
  $theEditable = 0 if $theEditable && !$topicObj->haveAccess("change");
  $theEditable = 0 if $context->{preview} || $context->{save};

  my $editIcon = '';
  my $inlineEditorClass = '';
  if ($theEditable) {
    Foswiki::Plugins::JQueryPlugin::createPlugin("InlineEditor");
    $editIcon = '<noautolink><a class="inlineEditButton" title="%MAKETEXT{"Edit [_1]" args="$name"}%">%JQICON{"'.$theEditIcon.'"}%</a></noautolink>';
    $inlineEditorClass = 'inlineEditor';
  }

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

  # get defaults from template
  my $theType = $params->{type} || '';
  $theType = 'div' if !Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid';
  $theType = 'table' unless $theType =~ /^(div|table|grid)$/;

  if (!defined($params->{format}) && !defined($theHeader) && !defined($theFooter)) {

    # table
    if ($theType eq 'table') {
      $theFooter = '</table></div>';
      if ($theEditable) {
        $theHeader = "<div class='foswikiFormSteps \$inlineEditor' data-topic='\$topic'><table class='foswikiLayoutTable'>";
      } else {
        $theHeader = "<div class='foswikiFormSteps'><table class='foswikiLayoutTable'>";
      }
    }

    # div
    elsif ($theType eq 'div') {
      $theFooter = '</div>';
      if ($theEditable) {
        $theHeader = "<div class='foswikiFormSteps \$inlineEditor' \$reload data-topic='\$topic'>";
      } else {
        $theHeader = "<div class='foswikiFormSteps'>";
      }
    }

    # grid
    elsif (Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid') {
      $theFooter = '%ENDGRID%</div>';
      if ($theEditable) {
        $theHeader = '<div class="foswikiPageForm foswikiGridForm $inlineEditor" \$reload data-topic="$topic">%BEGINGRID{gutter="1"}%';
      } else {
        $theHeader = '<div class="foswikiPageForm foswikiGridForm">%BEGINGRID{gutter="1"}%';
      }
    }
  }

  $theHeader ||= '';
  $theFooter ||= '';

  # make it compatible
  $theHeader =~ s/%A_TITLE%/\$title/g;
  $theFooter =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_VALUE%/\$value/g;

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
    my $fields = $form->getFields();
    @selectedFields = @$fields if defined $fields;
  }

  my @result = ();
  my $theLimit = $params->{limit} // 0;
  my $index = 1;
  foreach my $field (@selectedFields) {
    next unless $field;

    my $fieldName = $field->{name};
    my $fieldType = $field->{type};
    my $fieldSize = $field->{size};
    my $fieldAttrs = $field->{attributes};
    my $fieldDescription = $field->{tooltip} || $field->{description} || '';
    my $fieldTitle = $field->{title};
    my $fieldDefiningTopic = $field->{definingTopic};
    my $fieldReload = $theReload eq 'on' || $theReload =~ /\b$fieldName\b/ ? "true" : "false";

    # get the list of all allowed values
    my $fieldAllowedValues = '';
    # CAUTION: don't use field->getOptions() on a +values field as that won't return the full valueMap...only the value part, but not the title map
    if ($field->can('getOptions') && $field->{type} !~ /\+values/) {
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
      $fieldDefault = $field->getDefaultValue($thisWeb, $thisTopic) // '';
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
    $fieldAllowedValues = $params->{$fieldName . '_params'} if defined $params->{$fieldName . '_params'};
    $fieldDefault = $params->{$fieldName . '_default'} if defined $params->{$fieldName . '_default'};
    $fieldValue = $params->{$fieldName . '_value'} if defined $params->{$fieldName . '_value'};
    $fieldType = $params->{$fieldName . '_type'} if defined $params->{$fieldName . '_type'};
    $fieldType = $typeMapping{$fieldType} if defined $typeMapping{$fieldType};

    $fieldValue = $fieldDefault unless defined $fieldValue && $fieldValue ne '';
    next if $theHideEmpty && (!defined($fieldValue) || $fieldValue eq '');

    next if $theIncludeValue && $fieldValue !~ /$theIncludeValue/i;
    next if $theExcludeValue && $fieldValue =~ /$theExcludeValue/i;
    next if $theInclude && $fieldName !~ /$theInclude/;
    next if $theExclude && $fieldName =~ /$theExclude/;
    next if $theIncludeAttr && $fieldAttrs !~ /$theIncludeAttr/i;
    next if $theExcludeAttr && $fieldAttrs =~ /$theExcludeAttr/i;

    my $fieldAutolink = Foswiki::Func::isTrue($params->{$fieldName . '_autolink'}, $theAutolink);

    my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName . '_sort'}, $theSort);
    $fieldAllowedValues = $this->sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

    my $fieldFormat = $this->getFormat($params, $topicObj, $field);

    # temporarily remap field to another type
    my $fieldClone;
    if ( $fieldType ne $field->{type}
      || $params->{$fieldName . '_size'}
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
    $line =~ s/%A_TITLE%/\$title/g;
    $line =~ s/%A_VALUE%/\$value/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;

    # For Foswiki > 1.2, treat $value ourselves to get a consistent
    # behavior across all releases:
    # - patch in (display) value as $value
    # - use raw value as $origvalue
    my $origValue = $fieldValue;

    $this->translateField($field, $thisWeb, $theForm);

    # now dive into the core and see what we get out of it
    my $displayValue;
    if ($field->can("getDisplayValue")) {
      $displayValue = $field->getDisplayValue($fieldValue, $thisWeb, $thisTopic);
    } else {
      $displayValue = $field->renderForDisplay('$value(display)', $fieldValue, undef, $topicObj); # SMELL: topicObj is not supported everywhere
    }

    next if $theHideEmpty && (!defined($displayValue) || $displayValue eq '');

    # render this by ourselfs
    $line =~ s/\$editicon\b/$editIcon/g;
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
    $line =~ s/\$reload\b/$fieldReload/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;

    last if $theLimit && $index >= $theLimit;
    $index++;
  }

  return '' if $theHideEmpty && !@result;

  my $result = $theHeader . join($theSep, @result) . $theFooter;
  $result =~ s/\$topic\b/$thisWeb.$thisTopic/g;
  $result =~ s/\$inlineEditor\b/$inlineEditorClass/g;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  return $result;
}

sub getFormat {
  my ($this, $params, $meta, $field) = @_;

  my $theFormat;

  $theFormat = $params->{$field->{name}."_format"} if defined $field;
  $theFormat //= $params->{format};

  my $theType = $params->{type} || '';
  $theType = 'div' if !Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid';
  $theType = 'table' unless $theType =~ /^(div|table|grid)$/;

  my $theEditable;

  $theEditable = Foswiki::Func::isTrue($params->{editable}, 0);
  $theEditable = 0 if $theEditable && !$meta->haveAccess("change");
  $theEditable = 0 unless $field->isEditable();

  return $theFormat if defined $theFormat;

  # table
  if ($theType eq '' || $theType eq 'table') { 
    if ($theEditable) {
      $theFormat = <<'HERE';
<tr>
        <th class="foswikiTableFirstCol"> $title: </th>
        <td class="foswikiFormValue inlineEditValue" data-formfield="$name" data-reload="$reload"> 
$value <!-- -->
$editicon
      </td>
    </tr>
HERE
    } else {
      $theFormat = <<'HERE';
<tr>
        <th class="foswikiTableFirstCol"> $title: </th>
        <td class="foswikiFormValue"> 
$value <!-- -->
      </td>
    </tr>
HERE
    }

    return $theFormat;
  } 

  # div
  if ($theType eq 'div') { 
    if ($theEditable) {
      $theFormat = <<'HERE';
<div class='foswikiFormStep'>
<h3> $title </h3>
<div class='inlineEditValue' data-formfield='$name' data-reload='$reload'>
$value <!-- -->
$editicon
</div>
</div>
HERE
    } else {
      $theFormat = <<'HERE';
<div class='foswikiFormStep'>
<h3> $title </h3>
$value <!-- -->
</div>
HERE
    }
    return $theFormat;
  } 

  # grid
  if (Foswiki::Func::getContext()->{GridLayoutPluginEnabled} && $theType eq 'grid') {
    if ($theEditable) {
      $theFormat = <<'HERE';
%BEGINCOL{"3" class="foswikiGridHeader"}% 
<h3 >$title:</h3>
%BEGINCOL{"9"}%
<div class='inlineEditValue' data-formfield='$name' data-reload='$reload'>
$value <!-- -->
$editicon
</div>
HERE
    } else {
      $theFormat = <<'HERE';
%BEGINCOL{"3" class="foswikiGridHeader"}% 
<h3 >$title:</h3>
%BEGINCOL{"9"}%
$value
HERE
    }
   
    return $theFormat;
  }
  
  return "";
}

1;

