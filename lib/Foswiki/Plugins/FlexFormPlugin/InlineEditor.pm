# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2022 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexFormPlugin::InlineEditor;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Contrib::JsonRpcContrib::Error();
use Foswiki::UI::Save      ();
use Foswiki::OopsException ();
use Foswiki::Plugins::FlexFormPlugin ();
use Error qw( :try );

our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
  my $class = shift;

  my $this = bless(
    $class->SUPER::new(
      name => 'InlineEditor',
      version => $Foswiki::Plugins::FlexFormPlugin::VERSION,
      author => 'Michael Daum',
      homepage => 'http://foswiki.org/Extensions/FlexFormPlugin',
      css => ['inlineEditor.css'],
      javascript => ['inlineEditor.js'],
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/FlexFormPlugin',
      dependencies => ['foswikitemplate', 'pnotify', 'ui', 'jsonrpc', 'ajaxform', 'validate']
    ),
    $class
  );

  return $this;
}

sub jsonRpcSave {
  my ($this, $session, $request) = @_;

  my $wikiName = Foswiki::Func::getWikiName();

  my $web = $session->{webName};
  my $topic = $session->{topicName};

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission('change', $wikiName, undef, $topic, $web);

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist")
    unless Foswiki::Func::topicExists($web, $topic);

  # enter save context
  Foswiki::Func::getContext()->{save} = 1;

  # do a normal save
  my $error;
  try {
    Foswiki::UI::Save::save($session);
  } catch Foswiki::OopsException with {
    $error = shift->stringify();
    $error =~ s/ at .*$//;
    $error =~ s/ via .*$//;
  };

  $session->{response}->deleteHeader("Location", "Status");

  if ($error) {
    throw Foswiki::Contrib::JsonRpcContrib::Error("419", $error);
  }

  return "ok";
}

sub jsonRpcLockTopic {
  my ($this, $session, $request) = @_;

  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($session->{webName}, $request->param("topic") || $session->{topicName});

  my (undef, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);
  my $lockWikiName = Foswiki::Func::getWikiName($loginName);
  my $wikiName = Foswiki::Func::getWikiName();

  # TODO: localize
  if ($loginName && $wikiName ne $lockWikiName) {
    my $time = int($unlockTime);
    if ($time > 0) {
      throw Foswiki::Contrib::JsonRpcContrib::Error(423, "Topic is locked by $lockWikiName for another $time minute(s). Please try again later.");
    }
  }

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission('change', $wikiName, undef, $topic, $web);

  Foswiki::Func::setTopicEditLock($web, $topic, 1);

  return 'ok';
}

sub jsonRpcUnlockTopic {
  my ($this, $session, $request) = @_;

  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($session->{webName}, $request->param("topic") || $session->{topicName});
  my (undef, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);

  return 'ok' unless $loginName;    # nothing to unlock

  my $lockWikiName = Foswiki::Func::getWikiName($loginName);
  my $wikiName = Foswiki::Func::getWikiName();

  if ($lockWikiName ne $wikiName) {
    throw Foswiki::Contrib::JsonRpcContrib::Error(500, "Can't clear lease of user $lockWikiName")
      if $request->param("warn") ne 'off';
  } else {
    Foswiki::Func::setTopicEditLock($web, $topic, 0);
  }

  return 'ok';
}

1;
