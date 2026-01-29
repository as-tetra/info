#!/usr/bin/perl

###
#
#	$Id: randomentries.pl,v 1.8 2002/12/27 03:25:06 rayners Exp $
#
#	MTRandomEntries, version 0.5 by David Raynes <rayners@rayners.org>
#
###

use strict;
use MT::Template::Context;
use MT::Comment;

MT::Template::Context->add_container_tag (RandomEntries => \&randomEntries );

sub randomEntries {
  my ($ctx, $args, $cond) = @_;

  my $blog_id = $ctx->stash ('blog_id');
  my @entries;

  my $catLabel;
  if ($args->{category}) {
    $catLabel = $args->{category};
  } elsif ($ctx->{inside_mt_categories}) {
    require MT::Category;
    my $cat = $ctx->stash ('category');
    $catLabel = $cat->label;
  } elsif (my $entry = $ctx->stash ('entry')) {
    my $cats = $entry->categories;
    $catLabel = join (' OR ', @$cats);
  } 

  if ($catLabel) {
    require MT::Placement;
    if ($catLabel =~ /\s+(?:AND|OR)\s+/) {
      return $ctx->error(MT->translate(
	    "You can't use both AND and OR in the same expression ([_1]).",
	    $catLabel )) if $catLabel =~ /AND/ && $catLabel =~ /OR/;
      my @cats = split /\s+(?:AND|OR)\s+/, $catLabel;
      my %entries;
      for my $name (@cats) {
	my $cat = MT::Category->load ({ label => $name, blog_id => $blog_id })
	  or return $ctx->error(MT->translate(
		"No such category '[_1]'", $name));
	my @place = MT::Placement->load ({ category_id => $cat->id });
	for my $place (@place) {
	  $entries{$place->entry_id}++;
	}
      }
      my $is_and = $catLabel =~ /AND/;
      my $count = @cats;
      my @ids = $is_and ? grep { $entries{$_} == $count } keys %entries :
	keys %entries;
      for my $entry_id (@ids) {
	my $entry = MT::Entry->load ($entry_id);
	push @entries, $entry if $entry->status == MT::Entry::RELEASE();
      }
    } else {
      my $cat = MT::Category->load ({ label => $catLabel, blog_id => $blog_id })
	or return $ctx->error (MT->translate(
	      "No such category '[_1]'", $catLabel));
      my @place = MT::Placement->load ({ category_id => $cat->id });
      for my $p (@place) {
      	my $entry = MT::Entry->load ($p->entry_id);
	push @entries, $entry
	  if $entry->status == MT::Entry::RELEASE();
      }
    }
  } else {
    @entries = MT::Entry->load ({ blog_id => $blog_id,
	status => MT::Entry::RELEASE() });
  }

  srand;

  my $builder = $ctx->stash ('builder');
  my $tokens = $ctx->stash ('tokens');

  my %usedEntries;
  my $res;
  
  my $lastn = $args->{lastn} || 1;
  $lastn = @entries if ($lastn > @entries);
  while ($lastn > 0) {
    my $randEntry = $entries[ rand @entries ];
    while ($usedEntries{$randEntry->id}) {
      $randEntry = $entries[ rand @entries ];
    }
    $usedEntries{$randEntry->id}++;
#$ctx->stash ('entry', $randEntry);
    local $ctx->{__stash}{entry} = $randEntry;
    local $ctx->{current_timestamp} = $randEntry->created_on;
    defined(my $out = $builder->build($ctx, $tokens, {
	  EntryIfExtended => $randEntry->text_more ? 1 : 0,
	  EntryIfAllowComments => $randEntry->allow_comments,
	  EntryIfAllowPings => $randEntry->allow_pings}))
      or return $ctx->error($ctx->errstr);
    $res .= $out;
    $lastn--;
  }
  $res;
}
