# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2014 Michael Daum http://michaeldaumconsulting.com
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

our $VERSION = '3.10';
our $RELEASE = '3.10';
our $SHORTDESCRIPTION = 'Flexible way to render <nop>DataForms';
our $NO_PREFS_IN_TOPIC = 1;
our $doneInit;
our $baseWeb;
our $baseTopic;

##############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler('RENDERFOREDIT', sub {
    init();
    return Foswiki::Plugins::FlexFormPlugin::Core::handleRENDERFOREDIT(@_);
  });

  Foswiki::Func::registerTagHandler('RENDERFORDISPLAY', sub {
    init();
    return Foswiki::Plugins::FlexFormPlugin::Core::handleRENDERFORDISPLAY(@_);
  });

  Foswiki::Func::registerTagHandler('RENDERFORMDEF', sub {
    init();
    return Foswiki::Plugins::FlexFormPlugin::Core::handleRENDERFORMDEF(@_);
  });

  $doneInit = 0;
  return 1;
}

###############################################################################
sub init {
  return if $doneInit;
  $doneInit = 1;
  require Foswiki::Plugins::FlexFormPlugin::Core;
  Foswiki::Plugins::FlexFormPlugin::Core::init($baseWeb, $baseTopic);
}

###############################################################################
# deprecated to be used as a finish handler
sub modifyHeaderHandler {
  init();
  return Foswiki::Plugins::FlexFormPlugin::Core::finish(@_);
}

###############################################################################
sub completePageHandler {
  $_[0] =~ s/<\/?literal>//g;
}


1;

