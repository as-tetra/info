
package MT::Plugin::MultiBlog;

use base qw( MT::Plugin );
use vars qw( $VERSION $plugin );

use strict;
use MT::Template::Context;
use MT::Util qw( start_end_day start_end_week start_end_month
                 html_text_transform munge_comment archive_file_for
                 format_ts offset_time_list first_n_words dirify get_entry
                 encode_html encode_js remove_html wday_from_ts days_in
                 spam_protect encode_php encode_url decode_html encode_xml
                 decode_xml );

use MT::Promise qw( force delay );

use lib 'plugins/MultiBlog/lib';

use Data::Dumper;
use MT::Comment;
use MT::TBPing;

use MT;

sub BEGIN {
    $VERSION = '2.0';
    $plugin = MT::Plugin::MultiBlog->new ({
            name		=> 'MultiBlog',
            description	=> 'MultiBlog allows you to define blog rebuild dependencies and include templated content from other blogs.  <strong>For MT 3.x only</strong>',
            version		=> $VERSION,
            plugin_link	=> 'http://www.rayners.org/plugins/multiblog/',
            author_name	=> 'David Raynes',
            author_link	=> 'http://www.rayners.org/',
            system_config_template => 'system_config.tmpl',
            blog_config_template => 'blog_config.tmpl',
            settings	=> new MT::PluginSettings ([
                ['default_access', { Default => 1, Scope => 'system' }],
                ['rebuild_triggers', { Default => '', Scope => 'blog' }],
                ['other_triggers', { Scope => 'blog' }],
                ['default_includes', { Default => '', Scope => 'blog' }],
                ['access_controls', { Default => '', Scope => 'blog' }],
                ]),
            });
    MT->add_plugin ($plugin);
    if (MT->version_number < 3.3) {
        MT->add_callback ('CMSPostEntrySave', 10, $plugin, sub { post_entry_save($plugin, @_) });
    }
    else {
        MT->add_callback('CMSPostSave.entry', 10, $plugin, sub { post_entry_save($plugin, @_) });
    }
    MT::Comment->add_callback ('post_save', 10, $plugin, sub { post_feedback_save($plugin, "comment_pub", @_) });
    MT::TBPing->add_callback ('post_save', 10, $plugin, sub { post_feedback_save($plugin, "tb_pub", @_) });
}

sub perform_mb_action {
    my ($app, $blog_id, $action) = @_;

# If the action we are performing starts with ri
# we rebuild indexes for the given blog_id
    if ($action =~ /^ri/) {
        $app->rebuild_indexes (BlogID => $blog_id);

# And if the action contains a p
# we send out pings for the given blog_id too
        if ($action =~ /p/) {
            $app->ping (BlogID => $blog_id);
        }
    } 
  
# If the action is composed of rc followed by one or more digits
# it indicates that a category archive (the id of which is the digits)
# needs to be rebuilt
    elsif ($action =~ /^rc(\d+)$/) {
        my $cat_id = $1;

# Load the category to be certain it exists and belongs to the blog in
# question
        require MT::Category;
        my $cat = MT::Category->load ($cat_id);
        return if ($cat->blog_id != $blog_id);

# Rebuild the category archive
        require MT::Blog;
        $app->publisher->_rebuild_entry_archive_type (
	        Blog	    => MT::Blog->load ($blog_id),
	        Category	=> $cat,
	        ArchiveType	=> 'Category',
	    );
    }
}

sub post_feedback_save {
    my $plugin = shift;
    my ($trigger, $eh, $feedback) = @_;
    if ($feedback->visible) {
        my $blog_id = $feedback->blog_id;
        my $d = $plugin->get_config_value('other_triggers', "blog:$blog_id");
        while (my ($id, $a) = each (%{$d->{$trigger}})) {
            map { perform_mb_action (MT->instance, $id, $_)} keys %$a;
        }
    }
}

sub post_entry_save {
    my $plugin = shift;
    my ($eh, $app, $entry) = @_;
    my $blog_id = $entry->blog_id;
    my $d = $plugin->get_config_value ('other_triggers', "blog:$blog_id");
    while (my ($id, $a) = each (%{$d->{'entry_save'}})) {
        map { perform_mb_action ($app, $id, $_)} keys %$a;
    }

    require MT::Entry;
    if ($entry->status == MT::Entry::RELEASE()) {
        while (my ($id, $a) = each (%{$d->{'entry_pub'}})) {
            map { perform_mb_action ($app, $id, $_)} keys %$a;
        }
    }

}

sub load_config {
    my $plugin = shift;
    $plugin->SUPER::load_config (@_);
    if ($_[1] =~ /blog:(\d+)/) {
        my $blog_id = $1;

        require MT::Blog;
        my @b = sort { $a->name cmp $b->name } grep { $_->id != $blog_id } MT::Blog->load ();
        $_[0]->{multiblog_blog_loop} = [ map { { blog_id => $_->id, blog_name => $_->name } } @b ];
        my %blogs = map { $_->id => $_->name } @b;

        my @triggers = (
                { trigger_key => 'entry_save', trigger_name => 'saves an entry' },
                { trigger_key => 'entry_pub', trigger_name => 'publishes an entry' },
                { trigger_key => 'comment_pub', trigger_name => 'publishes a comment' },
                { trigger_key => 'tb_pub', trigger_name => 'publishes a ping' },
                );
        my %triggers = map { $_->{trigger_key} => $_->{trigger_name} } @triggers;

        $_[0]->{multiblog_trigger_loop} = [ @triggers ];

        my @actions = (
                { action_id => 'ri', action_name => 'Rebuild Indexes' },
                { action_id => 'rip', action_name => 'Rebuild Indexes and Send Pings' },
                );

        require MT::Category;

        push @actions, map { { action_id => 'rc'.$_->id, action_name => "Rebuild: ".$_->label } } 
        sort { $a->label cmp $b->label } MT::Category->load ({blog_id => $blog_id });

        my %actions = map { $_->{action_id} => $_->{action_name} } @actions;	    
        $_[0]->{multiblog_action_loop} = [ @actions ];

        my $rebuild_triggers = $_[0]->{rebuild_triggers};
        my @rebuilds = map { my ($action, $id, $trigger) = split (/:/, $_); 
            { action_name => $actions{$action}, action_value => $action,
                blog_name => $blogs{$id}, blog_id => $id,
                trigger_name => $triggers{$trigger}, trigger_value => $trigger } } split (/\|/, $rebuild_triggers);
            $_[0]->{rebuilds_loop} = [ @rebuilds ];
    }
}

sub save_config {
    my $plugin = shift;
    $plugin->SUPER::save_config (@_);

    if ($_[1] =~ /blog:(\d+)/) {
        my $blog_id = $1;
        my $rebuild_triggers = $_[0]->{rebuild_triggers};
        my $old_triggers = $_[0]->{old_rebuild_triggers};

# Check to see if the triggers changed
        if ($old_triggers ne $rebuild_triggers) {

# If so, remove all references to the current blog from the triggers cached in other blogs
            foreach (split (/\|/, $old_triggers)) {
                my ($action, $id, $trigger) = split (/:/, $_);
                my $d = $plugin->get_config_value('other_triggers', "blog:$id");
                delete $d->{$trigger}->{$blog_id} if (exists $d->{$trigger}->{$blog_id});
                $plugin->set_config_value('other_triggers', $d, "blog:$id");
            }
        }
        foreach (split (/\|/, $rebuild_triggers)) {
            my ($action, $id, $trigger) = split (/:/, $_);
            my $d = $plugin->get_config_value('other_triggers', "blog:$id");
            $d = {} if (!$d);
            $d->{$trigger}->{$blog_id}->{$action}++;
            $plugin->set_config_value('other_triggers', $d, "blog:$id");
        }
    }
}

sub reset_config {
    my $plugin = shift;
    if ($_[1] =~ /blog:(\d+)/) {
        my $blog_id = $1;

# Get the blogs this one triggers from and update them
# And then save the triggers this blog runs
        my $other_triggers = $plugin->get_config_value('other_triggers', $_[1]);
        my $rebuild_triggers = $plugin->get_config_value('rebuild_triggers', $_[1]);

        foreach (split (/\|/, $rebuild_triggers)) {
            my ($action, $id, $trigger) = split (/:/, $_);
            my $d = $plugin->get_config_value('other_triggers', "blog:$id");
            delete $d->{$trigger}->{$blog_id} if (exists $d->{$trigger}->{$blog_id});
            $plugin->set_config_value('other_triggers', $d, "blog:$id");
        }
        $plugin->SUPER::reset_config(@_);
        $plugin->set_config_value('other_triggers', $other_triggers, "blog:$blog_id");
    } else {
        $plugin->SUPER::reset_config(@_);
    }
}

sub init_app {
  my $plugin = shift;
  my ($app) = @_;

  if ($app->isa ('MT::App::CMS')) {
  }
}

MT::Template::Context->add_container_tag (OtherBlog => \&other_blog );
MT::Template::Context->add_container_tag (MultiBlog => \&other_blog );

sub other_blog {
  require MultiBlog::Tags::MultiBlog;
  &MultiBlog::Tags::MultiBlog::multiblog (@_);
}

MT::Template::Context->add_container_tag(MultiBlogEntries => \&MTMultiBlogEntries );
MT::Template::Context->add_container_tag(MultiBlogComments => \&MTMultiBlogComments );
MT::Template::Context->add_container_tag(MultiBlogCategories => \&MTMultiBlogCategories );
MT::Template::Context->add_container_tag(MultiBlogPings => \&MTMultiBlogPings );

MT::Template::Context->add_container_tag(MultiBlogArchiveList => \&MTMultiBlogArchiveList );

MT::Template::Context->add_tag(MultiBlogInclude => \&MTMultiBlogInclude );
MT::Template::Context->add_container_tag(MultiBlogLocalBlog => \&MTMultiBlogLocalBlog);

MT::Template::Context->add_conditional_tag (MultiBlogBlogHeader => \&MTMultiBlogBlogHeader);
MT::Template::Context->add_conditional_tag (MultiBlogBlogFooter => \&MTMultiBlogBlogFooter);

sub MTMultiBlogEntries {
  require MultiBlog::Tags::Entries;
  &MultiBlog::Tags::Entries::entries (@_);
}

sub MTMultiBlogComments {
  require MultiBlog::Tags::Comments;
  &MultiBlog::Tags::Comments::comments (@_);
}

sub MTMultiBlogCategories {
  require MultiBlog::Tags::Categories;
  &MultiBlog::Tags::Categories::categories (@_);
}

sub MTMultiBlogPings {
  require MultiBlog::Tags::Pings;
  &MultiBlog::Tags::Pings::pings (@_);
}

sub MTMultiBlogInclude {
  require MultiBlog::Tags::Include;
  &MultiBlog::Tags::Include::include (@_);
}

sub MTMultiBlogLocalBlog {
  require MultiBlog::Tags::LocalBlog;
  &MultiBlog::Tags::LocalBlog::local_blog (@_);
}

sub MTMultiBlogBlogHeader {
  my ($ctx, $args, $cond) = @_;
  return $cond->{'MultiBlogBlogHeader'};
}

sub MTMultiBlogBlogFooter {
  my ($ctx, $args, $cond) = @_;
  return $cond->{'MultiBlogBlogFooter'};
}

###### Conditional Tags

MT::Template::Context->add_conditional_tag(MultiBlogIfNotLocalBlog => sub {
	return defined ($_[0]->stash('local_blog_id')) && $_[0]->stash('local_blog_id') != $_[0]->stash('blog_id')
});
MT::Template::Context->add_conditional_tag(MultiBlogIfLocalBlog => sub {
	return !defined ($_[0]->stash('local_blog_id')) || $_[0]->stash('local_blog_id') == $_[0]->stash('blog_id')
});

###### MultiBlog Item

MT::Template::Context->add_container_tag(MultiBlogEntry => sub {
	my ($ctx, $args, $cond) = @_;
	require MT::Entry;
	return _global_item('Entry', $ctx, $args, sub { {
            EntryIfExtended => $_[0]->text_more ? 1 : 0,
            EntryIfAllowComments => $_[0]->allow_comments,
            EntryIfAllowPings => $_[0]->allow_pings,
        }});
});

MT::Template::Context->add_container_tag(MultiBlogComment => sub {
	my ($ctx, $args) = @_;
	require MT::Comment;
	return _global_item('Comment', $ctx, $args);
});

MT::Template::Context->add_container_tag(MultiBlogCategory => sub {
	my ($ctx, $args) = @_;
	require MT::Category;
	return _global_item('Category', $ctx, $args);
});

MT::Template::Context->add_container_tag(MultiBlogPing => sub {
	my ($ctx, $args) = @_;
	require MT::TBPing;
	return _global_item('TBPing', $ctx, $args);
});

###### MultiBlog Item Count

MT::Template::Context->add_tag(MultiBlogEntryCount => sub {
    require MT::Entry;
    return _global_count($_[0], $_[1], 'MT::Entry', { status => MT::Entry::RELEASE() });
});

MT::Template::Context->add_tag(MultiBlogCommentCount => sub {
    require MT::Comment;
    return _global_count($_[0], $_[1], 'MT::Comment');
});

MT::Template::Context->add_tag(MultiBlogCategoryCount => sub {
    require MT::Category;
    return _global_count($_[0], $_[1], 'MT::Category');
});

MT::Template::Context->add_tag(MultiBlogPingCount => sub {
    require MT::TBPing;
    return _global_count($_[0], $_[1], 'MT::TBPing');
});


###### MultiBlog Listing



{

    my $cur;
    my %TypeHandlers = (
        Monthly => {
            group_end => sub {
                my $stamp = ref $_[1] ? $_[1]->created_on : $_[1];
                my $som = start_end_month($stamp,
                    $_[0]->stash('blog'));
                my $end = !$cur || $som == $cur ? 0 : 1;
                $cur = $som;
                $end;
            },
            section_title => sub {
                my $stamp = ref $_[1] ? $_[1]->created_on : $_[1];
                my $start =
                    start_end_month($stamp, $_[0]->stash('blog'));
                _hdlr_date($_[0], { ts => $start, 'format' => "%B %Y" });
            },
            section_timestamp => sub {
                my $period_start = ref $_[1] ? sprintf("%04d%02d%02d000000",
                                                       @{$_[1]}, 1)
                                             : $_[1];
                start_end_month($period_start, $_[0]->stash('blog'));
            },
            helper => \&start_end_month,
        },
    );

sub MTMultiBlogArchiveList {
    my ($ctx, $args, $cond) = @_;

    my $blog = $ctx->stash ('blog');
    my $at = $blog->archive_type;

    local $ctx->{__stash}{local_blog_id} = $blog->id;
    my @blog_ids = _include_blogs ($ctx, $args);
    my %blog_id_hash = map { $_ => 1 } @blog_ids;

    return '' if !$at || $at eq 'None';

    if (my $arg_at = $args->{archive_type}) {
	my %at = map { $_ => 1 } split /,/, $at;
	unless ($at{$arg_at}) {
	    return $ctx->error(MT->translate(
			"The archive type specified in MTArchiveList ('[_1]') ".
			"is not one of the chosen archive types in your blog " .
			"configuration.", $arg_at ));
	}
	$at = $arg_at;
    } elsif ($blog->archive_type_preferred) {
	$at = $blog->archive_type_preferred;
    } else {
	$at = (split /,/, $at)[0];
    }

# Restrict it to Monthly only for the time being
    return '' if $at ne 'Monthly';

    local $ctx->{current_archive_type} = $at;

    my %args;
    $args{'sort'} = 'created_on';
    $args{'direction'} = 'descend';

#    my $out = Dumper (\%TypeHandlers);
#    return $out;

    my $group_end = $TypeHandlers{$at}{group_end};
    my $sec_ts = $TypeHandlers{$at}{section_timestamp};
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $res = '';
    my $i = 0;
    my $n = $args->{lastn};

	my $iter = MT::Entry->load_iter({ status => MT::Entry::RELEASE() },
		\%args);
	my @entries;
	my $build_archive_item = sub {
	    my $entries = [@_];
	    local $ctx->{__stash}{entries} = delay(sub{$entries});
	    my($start, $end) = $sec_ts->($ctx, (ref $_[0] ? $_[0]->created_on : ""));
	    local $ctx->{current_timestamp} = $start;
	    local $ctx->{current_timestamp_end} = $end;
#            my $out = "Building archive list with start of '$start' and end of '$end' with the following entries<br><pre><code>".Dumper (\@entries)."</code></pre>";
	    defined(my $out = $builder->build($ctx, $tokens, $cond)) or
		return $ctx->error( $builder->errstr );
	    $res .= $out;
	};
# Here we build groups of entries; every time we come
# across one that satisfies group_end, we build the arvhie
# item for the existing group, and clear the list.
	while (my $entry = $iter->()) {
	    next if (!exists ($blog_id_hash{$entry->blog_id}));
	    if ($group_end->($ctx, $entry) && @entries) {
		&$build_archive_item(@entries);
		@entries = ();                       ## clear the entry list
		    last if $n && $i++ >= $n-1;
	    }
	    push @entries, $entry;
	}
	if (@entries) {
	    &$build_archive_item(@entries);
	}
#    }
    $res;
}

}
## _global_item($name, $ctx, $args, [ sub { { \%cond; } } ])

sub _global_item {
	my ($name, $ctx, $args, $fcond) = @_;
	my $class = "MT::$name";
	
	my $blog_id = $ctx->stash ('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;
	
	my $id = $args->{id} or return $ctx->error ('id argument required');

	my $builder = $ctx->stash ('builder');
	my $tokens = $ctx->stash ('tokens');

	if ($id =~ s/\[(\/?MT[^\]]+)\]/\<$1\>/g) {
	  my $tok = $builder->compile ($ctx, $id);
	  defined ($id = $builder->build ($ctx, $tok))
	    or return $ctx->error ($builder->errstr);
	}
	
	my $item = $class->load ($id)
	or return $ctx->error (MT->translate ("$name '[_1]' not found'", $id));

	my $local_blog = MT::Blog->load ($blog_id);
	$local_blog = MultiBlog->copy_blog ($local_blog);

	## Set up blog context
	my $blog = MT::Blog->load($item->blog_id)
		or return $ctx->error("can't load blog " . $item->blog_id);

	return $ctx->error ("Access to '".$blog->name."' has been denied") 
	  unless ($local_blog->can_access ($blog));
	
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
	
	my @blog_ids = _include_blogs($ctx, $args);
	my %blog_id_hash = map { $_ => 1 } @blog_ids;
	my $limit_blogs = %blog_id_hash ? scalar(keys(%blog_id_hash)) : 0;
	
	$terms->{blog_id} = $blog_id_hash{(keys %blog_id_hash)[0]} if $limit_blogs == 1;
#	if($limit_blogs <= 1) {
#		return scalar $class->count($terms, \%loadargs);
#	} else {
		my $count = 0;
		my $iter = $class->load_iter($terms, \%loadargs);
		while(my $item = $iter->()) {
			$count++ if $blog_id_hash{$item->blog_id};
		}
		return $count;
#	}
}

## Get a list of blogs to include in search
## Looks at include_blogs or exclude_blogs argument
## Returns empty list if all blogs should be included
sub _include_blogs {
	my ($ctx, $args) = @_;

	## Init to empty list
	my @blog_ids = ();

	my $local_blog_id = $ctx->stash ('local_blog_id');
	my $local_blog = MT::Blog->load ($local_blog_id);

	if ($args->{include_blogs}) {
      if ($args->{ include_blogs } eq 'all') {
        @blog_ids = map { $_->id } MT::Blog->load ();
      }
      else {
	    @blog_ids = split(/,\s*/, $args->{include_blogs});
      }
	} elsif ($args->{exclude_blogs}) {
		## Get explicitly excluded blogs
		my %exclude_blog_ids = ();
		foreach my $blog_id (split(",", $args->{exclude_blogs})) {
			$exclude_blog_ids{$blog_id} = 1;
		}

		## Add all blogs except those excluded
		my @blogs = MT::Blog->load();
		foreach my $blog (@blogs) {
		  push @blog_ids, $blog->id unless $exclude_blog_ids{$blog->id};
		}
	} elsif ($plugin->get_config_value('default_includes', 'blog:'.$local_blog_id)) {
	  @blog_ids = split(/,\s*/, $plugin->get_config_value('default_includes', 'blog:'.$local_blog_id));
	} else {
	  my @blogs = MT::Blog->load ();
	  foreach my $blog (@blogs) {
	    push @blog_ids, $blog->id;
	  }
	}

    @blog_ids = grep { _can_access ($local_blog_id, $_) } @blog_ids;

#	foreach my $blog_id (@blog_ids) {
#	  my $blog = MT::Blog->load ($blog_id);
#  	  delete $blog_ids{$blog_id} unless ($local_blog->can_access ($blog));
#	}

	return @blog_ids;
}

sub _can_access {
  my ($display_blog_id, $content_blog_id) = @_;

  if (my $access_controls = $plugin->get_config_value ('access_controls',
              "blog:$content_blog_id")) {
    return $access_controls->{ $display_blog_id } if (exists
            $access_controls->{ $display_blog_id });
  }

  return $plugin->get_config_value ('default_access', 'system');
}

sub _get_blog_categories {
  my ($ctx, $args, $blog_ids)  = @_;

  my $category = $args->{category};

  my %categories = ();

  require MT::Category;
  foreach my $id (@$blog_ids) {
    my $cat = MT::Category->load ({ blog_id => $id, label => $category })
      or next;
    $categories{$id} = $cat;
  }

  return %categories;
}
=cut
	
    if (MT::ConfigMgr->instance()->ObjectDriver =~ /DBI/
	    && MT::ConfigMgr->instance()->ObjectDriver !~ /sqlite/
	    && ($at ne 'Weekly') && ($at ne 'Individual'))
    {
	my $group_iter;
	if ($at eq 'Monthly') {
	    $group_iter = MT::Entry->count_group_by({
		    status => MT::Entry::RELEASE},
		    {group=>["extract(year from created_on)",
		    "extract(month from created_on)"],
		    sort=>"extract(year from created_on) desc,
		    extract(month from created_on) desc"})
		or return $ctx->error("Couldn't get monthly archive list");
	}

	return $ctx->error("Group iterator failed.")
	    unless defined($group_iter);
	my ($cnt, @grp);
	while ((($cnt, @grp) = $group_iter->()) && defined($cnt)) {
#               my $period_start = sprintf("%04d%02d%02d000000", @grp);
	    my($start, $end) = $sec_ts->($ctx, \@grp);
	    local $ctx->{current_timestamp} = $start;
	    local $ctx->{current_timestamp_end} = $end;
	    local $ctx->{__stash}{entries} = delay(sub{
		    my @entries = MT::Entry->load(
			{blog_id => ref $blog ? $blog->id : $blog,
			status => MT::Entry::RELEASE(),
			created_on => [$ctx->{current_timestamp},
			$ctx->{current_timestamp_end}]},
			{range => {created_on => 1}});
		    \@entries;
		    });
	    defined(my $out = $builder->build($ctx, $tokens, $cond)) or
		return $ctx->error( $builder->errstr );
	    $res .= $out;
	    last if $n && $i++ >= $n-1;
	}
    } else {
=cut

