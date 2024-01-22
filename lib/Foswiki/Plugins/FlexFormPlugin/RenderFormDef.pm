# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2024 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexFormPlugin::RenderFormDef;

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

  my $formName;
  if ($params->{topic}) {
    my $request = Foswiki::Func::getRequestObject();
    my $thisRev = $params->{revision} // $params->{rev} // $request->param("rev");
    my ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($theWeb, $params->{topic});
    my $obj = $this->getTopicObject($thisWeb, $thisTopic, $thisRev);
    $formName = $obj->getFormName();
  } else {
    $formName = $params->{_DEFAULT} || $params->{form} || $theTopic;
  }

  my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName($theWeb, $formName);

  my $theFormat = $params->{format};
  $theFormat = '$name' unless defined $theFormat;

  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator} || '';
  my $theFields = $params->{field} || $params->{fields};
  my $theExclude = $params->{exclude};
  my $theInclude = $params->{include};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theIncludeType = $params->{includetype};
  my $theExcludeType = $params->{excludetype};
  my $theIgnoreError = Foswiki::Func::isTrue($params->{ignoreerror}, 0);
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 0);

  my $form;
  try {
    $form = new Foswiki::Form($this->{session}, $formWeb, $formTopic);
  } catch Foswiki::OopsException with {
    # nop
  };
  return ($theIgnoreError?"":$this->inlineError("can't load form $formWeb.$formTopic")) unless $form;

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      $fieldName =~ s/\s*$//;
      $fieldName =~ s/^\s*//;
      my $field = $form->getField($fieldName);
      $this->writeDebug("WARNING: no field for '$fieldName' in $formWeb.$formWeb") unless $field;
      push @selectedFields, $field if $field;
    }
  } else {
    my $fields = $form->getFields();
    @selectedFields = @$fields if defined $fields;
  }

  if ($theSort) {
    @selectedFields = sort {$a->{title} cmp $b->{title}} @selectedFields;
  }

  my @result = ();
  foreach my $field (@selectedFields) {
    next unless $field;
    next if defined $theExclude && $field->{name} =~ /$theExclude/;
    next if defined $theInclude && $field->{name} !~ /$theInclude/;
    next if $theIncludeAttr && $field->{attributes} !~ /$theIncludeAttr/;
    next if $theExcludeAttr && $field->{attributes} =~ /$theExcludeAttr/;
    next if $theIncludeType && $field->{type} !~ /$theIncludeType/;
    next if $theExcludeType && $field->{type} =~ /$theExcludeType/;

    my $line = $theFormat;

    my $defaultValue = $field->getDefaultValue // "";
    my $value = $field->{value} // $defaultValue;

    my $description = $field->{tooltip} // $field->{description} // '';

    $line =~ s/\$name/$field->{name}/g;
    $line =~ s/\$title/$field->{title}/g;
    $line =~ s/\$type/$field->{type}/g;
    $line =~ s/\$size/$field->{size}/g;
    $line =~ s/\$attributes/$field->{attributes}/g;
    $line =~ s/\$(description|tooltip)/$description/g;
    $line =~ s/\$(definingtopic|definingTopic)/$field->{definingTopic}/g;
    $line =~ s/\$default/$defaultValue/g;
    $line =~ s/\$value/$value/g;

    push @result, $line;
  }

  return '' unless @result;

  my $result = $theHeader . join($theSep, @result) . $theFooter;
  $result =~ s/\$form/$formName/g;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  return $result;
}

1;


