# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2016 Michael Daum http://michaeldaumconsulting.com
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

our $VERSION = '5.20';
our $RELEASE = '08 Mar 2016';
our $SHORTDESCRIPTION = 'Flexible way to render <nop>DataForms';
our $NO_PREFS_IN_TOPIC = 1;
our $renderForEditInstance;
our $renderForDisplayInstance;
our $renderFormDefInstance;

sub initPlugin {

  Foswiki::Func::registerTagHandler('RENDERFOREDIT', \&renderForEdit);
  Foswiki::Func::registerTagHandler('RENDERFORDISPLAY', \&renderForDisplay);
  Foswiki::Func::registerTagHandler('RENDERFORMDEF', \&renderFormDef);

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

sub completePageHandler {
  $_[0] =~ s/<\/?literal>//g;
}

1;

