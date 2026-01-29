# Copyright 2004 Stepan Riha. This code cannot be redistributed without
# permission from www.nonplus.net.
#
# Based on functions in Context.pm in MovableType 2.51, Copyright Six Apart
#
# Documentation: http://www.nonplus.net/software/mt/GlobalListings.htm
#
# Version History
#
#	2.02 - December 9 2003
#	Added MTGlobalEntry, MTGlobalComment, MTGlobalCategory, MTGlobalPing
#	Added MTGlobalEntryCount, MTGlobalCommentCount, MTGlobalCategoryCount, MTGlobalPingCount
#	Added MTGlobalCategories, MTGlobalPings
#	Added MTIfGlobalBlog, MTIfNotGlobalBlog
#
#	1.05 - September 9 2003
#	Fixed recently_commented_on.
#
#	1.04 - August 29 2003
#	Fixed incorrect MTDateHeader, MTDateFooter, MTEntriesFooter when
#   using include_blogs/exclude_blogs
#
#	1.03 - July 28 2003
#	Fixed modified_on sorting
#
#	1.02 - Jan 19 2003
#	Added lastn_modified attribute to MTGlobalEntries.
#	Fixed some warningd.
#
#	1.01 - Jan 16 2003
#	Added MTGlobalListingsVersion tag.
#	Fixed problem with categories not being present.
#	Added strict checking.
#
#	1.0 - Jan 3 2003
#	Initial release
#

use strict;
package plugins::GlobalListins;
use MT::Template::Context;
use MT::Util qw( start_end_day start_end_week start_end_month
                 html_text_transform munge_comment archive_file_for
                 format_ts offset_time_list first_n_words dirify get_entry
                 encode_html encode_js remove_html wday_from_ts days_in
                 spam_protect encode_php encode_url decode_html encode_xml
                 decode_xml );
use vars qw( $VERSION );
my $VERSION = '2.02';

MT::Template::Context->add_tag(GlobalListingsVersion => sub { $VERSION } );
MT::Template::Context->add_container_tag(GlobalEntries => \&MTGlobalEntries );
MT::Template::Context->add_container_tag(GlobalComments => \&MTGlobalComments );
MT::Template::Context->add_container_tag(GlobalCategories => \&MTGlobalCategories );
MT::Template::Context->add_container_tag(GlobalPings => \&MTGlobalPings );

###### Conditional Tags

MT::Template::Context->add_conditional_tag(IfGlobalBlog => sub {
	return defined ($_[0]->stash('local_blog_id')) && $_[0]->stash('local_blog_id') != $_[0]->stash('blog_id')
});
MT::Template::Context->add_conditional_tag(IfNotGlobalBlog => sub {
	return !defined ($_[0]->stash('local_blog_id')) || $_[0]->stash('local_blog_id') == $_[0]->stash('blog_id')
});

###### Global Item

MT::Template::Context->add_container_tag(GlobalEntry => sub {
	my ($ctx, $args, $cond) = @_;
	require MT::Entry;
	return _global_item('Entry', $ctx, $args, sub { {
            EntryIfExtended => $_[0]->text_more ? 1 : 0,
            EntryIfAllowComments => $_[0]->allow_comments,
            EntryIfAllowPings => $_[0]->allow_pings,
        }});
});

MT::Template::Context->add_container_tag(GlobalComment => sub {
	my ($ctx, $args) = @_;
	require MT::Comment;
	return _global_item('Comment', $ctx, $args);
});

MT::Template::Context->add_container_tag(GlobalCategory => sub {
	my ($ctx, $args) = @_;
	require MT::Category;
	return _global_item('Category', $ctx, $args);
});

MT::Template::Context->add_container_tag(GlobalPing => sub {
	my ($ctx, $args) = @_;
	require MT::TBPing;
	return _global_item('TBPing', $ctx, $args);
});

###### Global Item Count

MT::Template::Context->add_tag(GlobalEntryCount => sub {
    require MT::Entry;
    return _global_count($_[0], $_[1], 'MT::Entry', { status => MT::Entry::RELEASE() });
});

MT::Template::Context->add_tag(GlobalCommentCount => sub {
    require MT::Comment;
    return _global_count($_[0], $_[1], 'MT::Comment');
});

MT::Template::Context->add_tag(GlobalCategoryCount => sub {
    require MT::Category;
    return _global_count($_[0], $_[1], 'MT::Category');
});

MT::Template::Context->add_tag(GlobalPingCount => sub {
    require MT::TBPing;
    return _global_count($_[0], $_[1], 'MT::TBPing');
});


###### Global Listing

sub MTGlobalEntries {
    my($ctx, $args, $cond) = @_;
    require MT::Entry;
    my @entries;

    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;

    my($cat, $author, $saved_entry_stash);
    if (my $author_name = $args->{author}) {
        require MT::Author;
        $author = MT::Author->load({ name => $author_name }) or
            return $ctx->error(MT->translate(
                "No such author '[_1]'", $author_name ));
    }
    my $no_resort = 0;
	my ($last, $offset, $limit_blogs);
	my %blog_ids;
	if (%$args) {
        my %terms = ( status => MT::Entry::RELEASE() );
        $terms{author_id} = $author->id if $author;
		%blog_ids = _include_blogs($args);

		$limit_blogs = %blog_ids ? scalar(keys(%blog_ids)) : 0;
		my %args;
		$terms{blog_id} = $blog_ids{(keys %blog_ids)[0]} if $limit_blogs==1;
        if ($cat) {
            require MT::Placement;
            $args{'join'} = [ 'MT::Placement', 'entry_id',
                              { category_id => $cat->id }, { unique => 1 } ];
        }
		$offset = $args->{offset} || 0;
        if ($last = $args->{lastn}) {
            $args{'sort'} = 'created_on';
            $args{direction} = 'descend';
            $args{limit} = $last if ($limit_blogs <= 1);
            $args{offset} = $offset if ($limit_blogs <= 1);
        } elsif ($last = $args->{lastn_modified}) {
            $args{'sort'} = 'modified_on';
            $args{direction} = 'descend';
            $args{limit} = $last if ($limit_blogs <= 1);
            $args{offset} = $offset if ($limit_blogs <= 1);
			$args->{sort_by} = 'modified_on' unless $args->{sort_by};
        } elsif (my $days = $args->{days}) {
            my @ago = offset_time_list(time - 3600 * 24 * $days,
                $ctx->stash('blog_id'));
            my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
                $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
            $terms{created_on} = [ $ago ];
            %args = ( range => { created_on => 1 } );
        } elsif (my $n = $args->{recently_commented_on}) {
            $args{'join'} = [ 'MT::Comment', 'entry_id',
				undef,
                { 'sort' => 'created_on',
                  direction => 'descend',
                  unique => 1,
                  limit => $n } ];
            $no_resort = 1;
        }
        
        ## Add range if inside of date archive
        if($ctx->{current_timestamp} && $ctx->{current_timestamp_end}) {
        	$terms{created_on} = [ $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ];
        	$args{range} = { created_on => 1 };
        }
        
        ## Load entries
        if ($limit_blogs <= 1) {
        	@entries = MT::Entry->load(\%terms, \%args);
        } else {
			@entries = grep { $blog_ids{$_->blog_id} && $offset-- <= 0 && (!defined($last) || $last-- > 0) }
					   MT::Entry->load(\%terms, \%args);
		}
    } else {
        my $days = $ctx->stash('blog')->days_on_index;
        my @ago = offset_time_list(time - 3600 * 24 * $days,
            $ctx->stash('blog_id'));
        my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
            $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
        @entries = MT::Entry->load({
                                     created_on => [ $ago ],
                                     status => MT::Entry::RELEASE() },
            { range => { created_on => 1 } });
		@entries = grep { $blog_ids{$_->blog_id} } @entries unless ($limit_blogs <= 1);
    }
    my $res = '';
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    unless ($no_resort) {
        my $so = $args->{sort_order} || $ctx->stash('blog')->sort_order_posts;
        my $col = $args->{sort_by} || 'created_on';
        @entries = $so eq 'ascend' ?
            sort { $a->$col() cmp $b->$col() } @entries :
            sort { $b->$col() cmp $a->$col() } @entries;
    }
    my($last_day, $next_day) = ('00000000') x 2;
    my $i = 0;
	my $skipped = 0;
	use MT::ConfigMgr;
	my $noPlacementCache = MT::ConfigMgr->instance->NoPlacementCache;
    for my $e (@entries) {
        local $ctx->{__stash}{entry} = $e;
        local $ctx->{current_timestamp} = $e->created_on;
        my $this_day = substr $e->created_on, 0, 8;
        my $next_day = $this_day;
        my $footer = 0;
        if (defined $entries[$i+1]) {
            $next_day = substr($entries[$i+1]->created_on, 0, 8);
            $footer = $this_day ne $next_day;
        } else { $footer++ }
        
		## Set up blog context
		my $blog = MT::Blog->load($e->blog_id)
            or return $ctx->error("can't load blog " . $e->blog_id);
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;
		MT::ConfigMgr->instance->NoPlacementCache(1) unless $e->blog_id == $blog_id;
		
		my $out = $builder->build($ctx, $tok, {
            %$cond,
            DateHeader => ($this_day ne $last_day),
            DateFooter => $footer,
            EntryIfExtended => $e->text_more ? 1 : 0,
            EntryIfAllowComments => $e->allow_comments,
            EntryIfAllowPings => $e->allow_pings,
            EntriesHeader => !$i,
            EntriesFooter => !defined $entries[$i+1],
        });
		MT::ConfigMgr->instance->NoPlacementCache($noPlacementCache);
        $last_day = $this_day;
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
        $i++;
    }

    ## Restore a saved entry stash. This is basically emulating "local",
    ## which we can't use, because the local would be buried too far down
    ## in a conditional.
    if ($saved_entry_stash) {
        if (!@$saved_entry_stash) {
            delete $ctx->{__stash}{entries};
        } else {
            $ctx->{__stash}{entries} = $saved_entry_stash;
        }
    }
    $res;
}


sub MTGlobalComments {
    my($ctx, $args, $cond) = @_;
    require MT::Entry;
    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;

	my ($last, $limit_blogs);
	my %blog_ids;

	%blog_ids = _include_blogs($args);
	$limit_blogs = %blog_ids ? scalar(keys(%blog_ids)) : 0;
	my (%args, %terms);
	$terms{blog_id} = $blog_ids{(keys %blog_ids)[0]} if $limit_blogs==1;

    my $so = $args->{sort_order} || 'descend';
	my $n = $args->{lastn};
	my $reverse = $n && $so eq 'ascend';
	my %loadargs = ( 'sort' => 'created_on', direction => $reverse ? 'descend' : $so );
	my $offset = $args->{offset} || 0;

	$loadargs{limit} = $n if $n && !$limit_blogs;
	$loadargs{offset} = $offset if !$limit_blogs;

	## Add range if inside of date archive
	if($ctx->{current_timestamp} && $ctx->{current_timestamp_end}) {
		$terms{created_on} = [ $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ];
		$loadargs{range} = { created_on => 1 };
	}

	my @comments = grep { ($limit_blogs <= 1 || $blog_ids{$_->blog_id}) || $offset-- > 0 }
                   MT::Comment->load(\%terms, \%loadargs);

	# Reverse, if neccessary
	@comments = reverse @comments if($reverse);

	my $html = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $i = 1;
	my $noPlacementCache = MT::ConfigMgr->instance->NoPlacementCache;
    for my $c (@comments) {
		$ctx->stash('comment' => $c);
        local $ctx->{current_timestamp} = $c->created_on;

		## Set up blog context
		my $blog = MT::Blog->load($c->blog_id)
            or return $ctx->error("can't load blog " . $c->blog_id);
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;

		$ctx->stash('comment_order_num', $i);
		MT::ConfigMgr->instance->NoPlacementCache(1) unless $c->blog_id == $blog_id;
        my $out = $builder->build($ctx, $tokens, $cond);
		MT::ConfigMgr->instance->NoPlacementCache($noPlacementCache);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $html .= $out;
        $i++;
#		last if $n && $i > $n;
    }
    $html;
}

sub MTGlobalCategories {
    my($ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;
    
	my %blog_ids = _include_blogs($args);;
	my $limit_blogs = %blog_ids ? scalar(keys(%blog_ids)) : 0;

    require MT::Category;
    require MT::Placement;
    my $iter = MT::Category->load_iter( ($limit_blogs==1) ? $blog_ids{(keys %blog_ids)[0]} : undef,
        { 'sort' => 'label', direction => 'ascend' });
    my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $needs_entries = ($ctx->stash('uncompiled') =~ /<\$?MTEntries/) ? 1 : 0;
    ## In order for this handler to double as the handler for
    ## <MTArchiveList archive_type="Category">, it needs to support
    ## the <$MTArchiveLink$> and <$MTArchiveTitle$> tags
    local $ctx->{inside_mt_categories} = 1;
	my $noPlacementCache = MT::ConfigMgr->instance->NoPlacementCache;
    while (my $cat = $iter->()) {
    	next unless $limit_blogs <= 1 || $blog_ids{$cat->blog_id};

        local $ctx->{__stash}{category} = $cat;
        local $ctx->{__stash}{entries};
        local $ctx->{__stash}{category_count};
        my @args = (
            { blog_id => $cat->blog_id,
              status => MT::Entry::RELEASE() },
            { 'join' => [ 'MT::Placement', 'entry_id',
                          { category_id => $cat->id } ],
              'sort' => 'created_on',
              direction => 'descend', });
        if ($needs_entries) {
            my @entries = MT::Entry->load(@args);
            $ctx->{__stash}{entries} = \@entries;
            $ctx->{__stash}{category_count} = scalar @entries;
        } else {
            $ctx->{__stash}{category_count} = MT::Entry->count(@args);
        }
        next unless $ctx->{__stash}{category_count} || $args->{show_empty};

		## Set up blog context
		my $blog = MT::Blog->load($cat->blog_id)
            or return $ctx->error("can't load blog " . $cat->blog_id);
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;
		MT::ConfigMgr->instance->NoPlacementCache(1) unless $cat->blog_id == $blog_id;
    	
        my $out = $builder->build($ctx, $tokens, $cond);

		MT::ConfigMgr->instance->NoPlacementCache($noPlacementCache);
        
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
    }
    $res;
}


sub MTGlobalPings {
    my($ctx, $args, $cond) = @_;
    require MT::Entry;
    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;

	my ($last, $limit_blogs);
	my %blog_ids;

	%blog_ids = _include_blogs($args);
	$limit_blogs = %blog_ids ? scalar(keys(%blog_ids)) : 0;
	my (%args, %terms);
	$terms{blog_id} = $blog_ids{(keys %blog_ids)[0]} if $limit_blogs==1;

    my $so = $args->{sort_order} || 'descend';
	my $n = $args->{lastn};
	my $reverse = $n && $so eq 'ascend';
	my %loadargs = ( 'sort' => 'created_on', direction => $reverse ? 'descend' : $so );
	my $offset = $args->{offset} || 0;

	$loadargs{limit} = $n if $n && !$limit_blogs;
	$loadargs{offset} = $offset if !$limit_blogs;

	## Add range if inside of date archive
	if($ctx->{current_timestamp} && $ctx->{current_timestamp_end}) {
		$terms{created_on} = [ $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ];
		$loadargs{range} = { created_on => 1 };
	}

	my @pings = grep { ($limit_blogs <= 1 || $blog_ids{$_->blog_id}) || $offset-- > 0 }
                   MT::TBPing->load(\%terms, \%loadargs);

	# Reverse, if neccessary
	@pings = reverse @pings if($reverse);

	my $html = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $i = 1;
	my $noPlacementCache = MT::ConfigMgr->instance->NoPlacementCache;
    for my $p (@pings) {
		$ctx->stash('ping' => $p);
        local $ctx->{current_timestamp} = $p->created_on;

		## Set up blog context
		my $blog = MT::Blog->load($p->blog_id)
            or return $ctx->error("can't load blog " . $p->blog_id);
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;

		MT::ConfigMgr->instance->NoPlacementCache(1) unless $p->blog_id == $blog_id;
        my $out = $builder->build($ctx, $tokens, $cond);
		MT::ConfigMgr->instance->NoPlacementCache($noPlacementCache);
        return $ctx->error( $builder->errstr ) unless defined $out;
        $html .= $out;
        $i++;
#		last if $n && $i > $n;
    }
    $html;
}

## _global_item($name, $ctx, $args, [ sub { { \%cond; } } ])

sub _global_item {
	my ($name, $ctx, $args, $fcond) = @_;
	my $class = "MT::$name";
	
	my $blog_id = $ctx->stash ('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;
	
	my $id = $args->{id} or return $ctx->error ('id argument required');
	
	my $item = $class->load ($id)
	or return $ctx->error (MT->translate ("$name '[_1]' not found'", $id));
	
	my $builder = $ctx->stash ('builder');
	my $tokens = $ctx->stash ('tokens');

	## Set up blog context
	my $blog = MT::Blog->load($item->blog_id)
		or return $ctx->error("can't load blog " . $item->blog_id);
	local $ctx->{__stash}{blog} = $blog;
	local $ctx->{__stash}{blog_id} = $blog->id;

	use MT::ConfigMgr;
	my $noPlacementCache = MT::ConfigMgr->instance->NoPlacementCache;
	MT::ConfigMgr->instance->NoPlacementCache(1) unless $item->blog_id == $blog_id;
	
	$name =~ tr/A-Z/a-z/;
	$name = 'ping' if $name eq 'tbping';	# TBPing is stashed as 'ping'
	local $ctx->{__stash}{$name} = $item;
	my $out = $builder->build ($ctx, $tokens, $fcond ? $fcond->($item) : undef);   ## Don't use $cond
	MT::ConfigMgr->instance->NoPlacementCache($noPlacementCache);
	
	return $ctx->error ($builder->errstr) unless defined $out;
	
	return $out;  
}

## _global_count(class, args, terms)
## _global_count('MT::Entry', $_[1], { status => MT::Entry::RELEASE() }
sub _global_count {
	my ($ctx, $args, $class, $terms) = @_;
	my %loadargs;
	$terms = {} unless defined $terms;

	## Add range if inside of date archive
	if($ctx->{current_timestamp} && $ctx->{current_timestamp_end}) {
		$terms->{created_on} = [ $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ];
		$loadargs{range} = { created_on => 1 };
	}
	
	my %blog_ids = _include_blogs($args);
	my $limit_blogs = %blog_ids ? scalar(keys(%blog_ids)) : 0;
	
	$terms->{blog_id} = $blog_ids{(keys %blog_ids)[0]} if $limit_blogs == 1;
	if($limit_blogs <= 1) {
		return scalar $class->count($terms, \%loadargs);
	} else {
		my $count = 0;
		my $iter = $class->load_iter($terms, \%loadargs);
		while(my $item = $iter->()) {
			$count++ if $blog_ids{$item->blog_id};
		}
		return $count;
	}
}

## Get a list of blogs to include in search
## Looks at include_blogs or exclude_blogs argument
## Returns empty list if all blogs should be included
sub _include_blogs {
	my $args = $_[0];

	## Init to empty list
	my %blog_ids = ();

	if ($args->{include_blogs}) {
		## Add explicitly included blogs
		foreach my $blog_id (split(",", $args->{include_blogs})) {
			$blog_ids{$blog_id} = $blog_id;
		}
	} elsif ($args->{exclude_blogs}) {
		## Get explicitly excluded blogs
		my %exlude_blog_ids = ();
		foreach my $blog_id (split(",", $args->{exclude_blogs})) {
			$exlude_blog_ids{$blog_id} = 1;
		}

		## Add all blogs except those excluded
		my @blogs = MT::Blog->load();
		foreach my $blog (@blogs) {
			$blog_ids{$blog->id} = $blog->id unless $exlude_blog_ids{$blog->id};
		}
	}

	return %blog_ids;
}

1;
