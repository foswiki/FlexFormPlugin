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

package Foswiki::Plugins::FlexFormPlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Contrib::JsonRpcContrib ();

our $VERSION = '8.42';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Flexible way to render <nop>DataForms';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;

our $renderForEditInstance;
our $renderForDisplayInstance;
our $renderFormDefInstance;

sub initPlugin {

  Foswiki::Func::registerTagHandler('RENDERFOREDIT', \&renderForEdit);
  Foswiki::Func::registerTagHandler('RENDERFORDISPLAY', \&renderForDisplay);
  Foswiki::Func::registerTagHandler('RENDERFORMDEF', \&renderFormDef);
  Foswiki::Func::registerTagHandler('DISPLAYFIELD', \&displayField);

  Foswiki::Func::registerTagHandler('EDITFIELD', \&editField);

  Foswiki::Plugins::JQueryPlugin::registerPlugin('InlineEditor', 'Foswiki::Plugins::FlexFormPlugin::InlineEditor');

  Foswiki::Contrib::JsonRpcContrib::registerMethod("FlexFormPlugin", "save", sub {
    my $inlineEditor = Foswiki::Plugins::JQueryPlugin::createPlugin("InlineEditor");
    return $inlineEditor->jsonRpcSave(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("FlexFormPlugin", "lock", sub {
    my $inlineEditor = Foswiki::Plugins::JQueryPlugin::createPlugin("InlineEditor");
    return $inlineEditor->jsonRpcLockTopic(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("FlexFormPlugin", "unlock", sub {
    my $inlineEditor = Foswiki::Plugins::JQueryPlugin::createPlugin("InlineEditor");
    return $inlineEditor->jsonRpcUnlockTopic(@_);
  });

  return 1;
}

sub renderForEdit {
  my $session = shift;

  unless ($renderForEditInstance) {
    require Foswiki::Plugins::FlexFormPlugin::RenderForEdit;
    $renderForEditInstance = Foswiki::Plugins::FlexFormPlugin::RenderForEdit->new($session);
  }

  return $renderForEditInstance->handle(@_);
}

sub renderForDisplay {
  my $session = shift;

  unless ($renderForDisplayInstance) {
    require Foswiki::Plugins::FlexFormPlugin::RenderForDisplay;
    $renderForDisplayInstance = Foswiki::Plugins::FlexFormPlugin::RenderForDisplay->new($session);
  }

  return $renderForDisplayInstance->handle(@_);
}

sub displayField {
  my ($session, $theParams, $theTopic, $theWeb) = @_;

  my %params = ();

  if (defined $theParams->{type} && !defined $theParams->{topic} && ! defined $theParams->{form}) {
    $params{form} = "System.MoreFormfieldsPlugin"; # SMELL: only advanced fields ... need a way to reference all available formfield types
    $params{field} = ucfirst($theParams->{type});
    $params{$params{field} . '_name'} = $theParams->{_DEFAULT} // $theParams->{field};
  } else {
    $params{form} = $theParams->{form};
    $params{topic} = $theParams->{topic} // $theTopic;
    $params{field} = $theParams->{_DEFAULT} // $theParams->{field};
    $params{$params{field} . "_name"} = $theParams->{name};
  }

  return "" unless defined $params{field};

  $params{excludeattr} = ""; # disable exclusion based on attributes, i.e. hidden fields
  $params{$params{field} . "_attributes"} = $theParams->{attributes};
  $params{$params{field} . "_default"} = $theParams->{default};
  $params{$params{field} . "_definition"} = $theParams->{definition};
  $params{$params{field} . "_size"} = $theParams->{size};
  $params{$params{field} . "_type"} = $theParams->{type};
  $params{$params{field} . "_value"} = $theParams->{value};
  $params{$params{field} . "_values"} = $theParams->{values};

  $params{rev} = $theParams->{revision} || $theParams->{rev};
  $params{editable} = $theParams->{editable} // 'off';
  $params{format} = $theParams->{format};
  $params{hideempty} = $theParams->{hideempty};

  unless (defined $params{format}) {
    if (Foswiki::Func::isTrue($params{editable})) {
      $params{format} = '<span class="inlineEditor" data-topic="$topic"><span class="inlineEditValue" data-formfield="$name">$n$value $editicon</span></span>';
    } else {
      $params{format} = '$value';
    }
  }

  return renderForDisplay($session, \%params, $theTopic, $theWeb);
}

sub editField {
  my ($session, $theParams, $theTopic, $theWeb) = @_;

  my %params = ();

  if (defined $theParams->{type} && !defined $theParams->{topic} && ! defined $theParams->{form}) {
    $params{form} = "System.MoreFormfieldsPlugin"; # SMELL: only advanced fields ... need a way to reference all available formfield types
    $params{field} = ucfirst($theParams->{type});
    $params{$params{field} . '_name'} = $theParams->{_DEFAULT} // $theParams->{field};
  } else {
    $params{form} = $theParams->{form};
    $params{topic} = $theParams->{topic} // $theTopic;
    $params{field} = $theParams->{_DEFAULT} // $theParams->{field};
    $params{$params{field} . "_name"} = $theParams->{name};
  }

  return "" unless defined $params{field};

  $params{$params{field} . "_type"} = $theParams->{type};
  $params{$params{field} . "_attributes"} = $theParams->{attributes};
  $params{$params{field} . "_default"} = $theParams->{default};
  $params{$params{field} . "_definition"} = $theParams->{definition};
  $params{$params{field} . "_size"} = $theParams->{size};
  $params{$params{field} . "_value"} = $theParams->{value};
  $params{$params{field} . "_values"} = $theParams->{values};

  $params{rev} = $theParams->{revision} || $theParams->{rev};
  $params{format} = $theParams->{format} // '$edit';

  return renderForEdit($session, \%params, $theTopic, $theWeb);
}

sub renderFormDef {
  my $session = shift;

  unless ($renderFormDefInstance) {
    require Foswiki::Plugins::FlexFormPlugin::RenderFormDef;
    $renderFormDefInstance = new Foswiki::Plugins::FlexFormPlugin::RenderFormDef($session)
  }

  return $renderFormDefInstance->handle(@_);
}

sub finishPlugin {

  $renderForEditInstance->finish() if $renderForEditInstance;
  $renderForDisplayInstance->finish() if $renderForDisplayInstance;
  $renderFormDefInstance->finish() if $renderFormDefInstance;

  $renderForEditInstance = undef;
  $renderForDisplayInstance = undef;
  $renderFormDefInstance = undef;
}

# SMELL: why is this located here???
sub completePageHandler {
  $_[0] =~ s/<\/?literal>//g;
}

1;

