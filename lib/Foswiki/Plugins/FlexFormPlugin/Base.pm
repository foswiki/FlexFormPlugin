# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2018 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexFormPlugin::Base;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Form();
#use Data::Dump qw(dump);

use constant TRACE => 0;    # toggle me
our %topicObjs = (); # shared among all classes

sub new {
  my $class = shift;
  my $session = shift;

  my $this = bless({
    session => $session,
    @_
  }, $class);

  return $this;
}

sub writeDebug {
  return unless TRACE;

  my ($this, $msg) = @_;
  print STDERR __PACKAGE__ . " - ". $msg . "\n";
}

sub getTopicObject {
  my ($this, $web, $topic, $rev) = @_;

  $web ||= '';
  $topic ||= '';
  $rev ||= '';

  $web =~ s/\//\./go;
  my $key = $web . '.' . $topic . '@' . $rev;
  my $topicObj = $topicObjs{$key};

  unless ($topicObj) {
    ($topicObj) = Foswiki::Func::readTopic($web, $topic, $rev);
    $topicObjs{$key} = $topicObj;
  }

  return $topicObj;
}

sub translate {
  my ($this, $text, $web, $topic) = @_;

  return "" unless defined $text && $text ne "";

  return $text unless Foswiki::Func::getContext()->{MultiLingualPluginEnabled};
  require Foswiki::Plugins::MultiLingualPlugin;
  return Foswiki::Plugins::MultiLingualPlugin::translate($text, $web, $topic);
}

sub translateField {
  my ($this, $field, $web, $topic) = @_;


  return unless $field;
  return unless $field->{type} =~ /\+values/;
  return unless Foswiki::Func::getContext()->{MultiLingualPluginEnabled};

  # populate valueMap
  return unless $field->{valueMap};

  while (my ($key, $val) = each %{$field->{valueMap}}) {
    $field->{valueMap}{$key} = $this->translate($val, $web, $topic);
  }
}

sub sortValues {
  my ($this, $values, $sort) = @_;

  my @values = split(/\s*,\s*/, $values);
  my $isNumeric = 1;
  foreach my $item (@values) {
    $item =~ s/\s*$//;
    $item =~ s/^\s*//;
    unless ($item =~ /^(\s*[+-]?\d+(\.?\d+)?\s*)$/) {
      $isNumeric = 0;
      last;
    }
  }

  if ($isNumeric) {
    @values = sort { $a <=> $b } @values;
  } else {
    @values = sort { lc($a) cmp lc($b) } @values;
  }

  @values = reverse @values if $sort =~ /(rev(erse)?)|desc(end(ing)?)?/;

  return join(', ', @values);
}

sub finish {
  my $this = shift;

  $this->{session} = undef;
  $this->{translator} = undef;
  %topicObjs = ();
}

sub inlineError {
  my ($this, $msg) = @_;

  return "<div class='foswikiAlert'>ERROR: ".$msg."</div>";
}

sub handle {
  die "not implemented in ".__PACKAGE__;
}

1;
