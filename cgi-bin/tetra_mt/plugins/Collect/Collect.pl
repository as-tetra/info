
# Collect.pl
# Movable Type plugin tags for collecting and displaying HTML tags 
# contained in entries
# by Kevin Shay
# http://www.staggernation.com/mtplugins/
# last modified July 12, 2004

package MT::Plugin::Collect;
use strict;
use vars qw( $VERSION );
$VERSION = '1.2';

use MT;
use MT::Template::Context;
use MT::Util qw( decode_html );

eval{ require MT::Plugin };
unless ($@) {
    my $plugin = {
        name => "Collect $VERSION",
        description => 'Collect and display HTML tags that appear within your entries.',
        doc_link => 'http://www.staggernation.com/mtplugins/Collect'
    }; 
    MT->add_plugin(new MT::Plugin($plugin));
}

MT::Template::Context->add_container_tag('Collect' => sub{&_hdlr_collect;});
MT::Template::Context->add_container_tag('CollectThis' => sub{&_hdlr_collect_this;});
MT::Template::Context->add_container_tag('Collected' => sub{&_hdlr_collected;});
MT::Template::Context->add_conditional_tag('IfCollected' => sub{&_hdlr_if_collected;});
MT::Template::Context->add_conditional_tag('IfCollectedAttr' => sub{&_hdlr_if_collected_attr;});
MT::Template::Context->add_conditional_tag('IfCollectedContent' => sub{&_hdlr_if_collected_content;});
MT::Template::Context->add_conditional_tag('IfCollectedSite' => sub{&_hdlr_if_collected_site;});
MT::Template::Context->add_container_tag('CollectedArchive' => sub{&_hdlr_collected_archive;});
MT::Template::Context->add_container_tag('CollectedEntryTags' => sub{&_hdlr_collected_entry_tags;});
MT::Template::Context->add_tag('CollectedTag' => sub{&_hdlr_collected_tag;});
MT::Template::Context->add_tag('CollectedContent' => sub{&_hdlr_collected_content;});
MT::Template::Context->add_tag('CollectedSite' => sub{&_hdlr_collected_site;});
MT::Template::Context->add_tag('CollectedAttr' => sub{&_hdlr_collected_attr;});
MT::Template::Context->add_tag('CollectedGroup' => sub{&_hdlr_collected_group;});
MT::Template::Context->add_tag('CollectedTotalCount' => sub{&_hdlr_collected_total_count;});
MT::Template::Context->add_tag('CollectedGroupCount' => sub{&_hdlr_collected_group_count;});
MT::Template::Context->add_tag('CollectedIndex' => sub{&_hdlr_collected_index;});

sub _hdlr_collect {
	my ($ctx, $args, $cond) = @_;
	defined (my $tags = $args->{'tags'})
		|| return $ctx->error('No tags specified');
	my $params = {};
	my %tags = map { $_ => 1 } split(/,/, $tags);
	my %urls = ();
	if (defined (my $urls = $args->{'urls'})) {
		%urls = map { $_ => 1 } split(/,/, $urls);
	}
	$params->{'tags'} = \%tags;
	$params->{'urls'} = \%urls;
		# total count of collected tag instances
	$params->{'abs_n'} = 0;
		# count of collected instances of each tag
	$params->{'ns'} = {};
		# these stash items will tell other tags they're being called properly
		# from within MTCollect
	local $ctx->{__stash}{'mtcollect_params'} = $params;
		# mtcollect_collection will hold the actual collected tags
	local $ctx->{__stash}{'mtcollect_collection'} = {};
	defined(my $text = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		|| return $ctx->error($ctx->errstr);
	return $text;
}

sub _hdlr_collect_this {
	my ($ctx, $args, $cond) = @_;
	defined (my $params = $ctx->stash('mtcollect_params'))
		|| return $ctx->error('Not called from within MTCollect container');
	defined (my $col = $ctx->stash('mtcollect_collection'))
		|| return $ctx->error('Not called from within MTCollect container');
	defined(my $text = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		|| return $ctx->error($ctx->errstr);
	my $show = $args->{'show'} ? 1 : 0;
	my $tags = join('|', keys %{$params->{'tags'}});
	my $entry_id;
	if (my $e = $ctx->stash('entry')) {
		$entry_id = $e->id;
	}
		# collect_tag() does all the actual collecting (and inserting
		# format strings, if applicable)
	$text =~ s!(<($tags)(\s+[^>]*)?>((.*?)</\2>)?)!
		collect_tag(
			$params, 
			$col,
			$1,
			$2,
			defined($3) ? $3 : '',
			defined($5) ? $5 : '',
			++$col->{'ns'}->{$2},
			++$col->{'abs_n'},
			$args->{$2},
			$entry_id)
		!iegs;
	$ctx->stash('mtcollect_collection', $col);
	return ($show ? $text : '');
}

sub _hdlr_if_collected {
	my ($ctx, $args, $cond) = @_;
	defined (my $params = $ctx->stash('mtcollect_params'))
		|| return $ctx->error('Not called from within MTCollect container');
	defined (my $col = $ctx->stash('mtcollect_collection'))
		|| return $ctx->error('Not called from within MTCollect container');
	my @tags = ();
	if (my $tags = $args->{'tags'}) {
		@tags = split(/,/, $tags);
	} else {
		@tags = keys %{$params->{'tags'}};
	}
	my $proceed = 0;
		# we show our contents if at least one instance of ANY (not all)
		# specified tags was collected
	OUTER:
	for my $tag (@tags) {
		if ($col->{$tag} && @{$col->{$tag}}) {
			for my $instance (@{$col->{$tag}}) {
				next if (defined($instance->{'_site'}) &&
					!$instance->{'_site'} && !$args->{'show_local'});
				$proceed = 1;
				last OUTER;
			}
		}
	}
	return $proceed;
}

sub _hdlr_collected {
	my ($ctx, $args, $cond) = @_;
	defined (my $params = $ctx->stash('mtcollect_params'))
		|| return $ctx->error('Not called from within MTCollect container');
	defined (my $col = $ctx->stash('mtcollect_collection'))
		|| return $ctx->error('Not called from within MTCollect container');
	my @tags = ();
	if (my $tags = $args->{'tags'}) {
		@tags = split(/,/, $tags);
	} else {
		@tags = keys %{$params->{'tags'}};
	}
	my $group_by = $args->{'group_by'} || '';
	my $sort_by = $args->{'sort_by'} || '';
	my $sort_order = $args->{'sort_order'} || '';
		# prepend _ to special elements to avoid potential conflict with
		# attribute names
	if ($group_by =~ /^content|site$/) {
		$group_by = '_' . $group_by;
	}
	my $lastn = $args->{'lastn'};
	my $min_count = $args->{'min_count'};
	my $text = '';
	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
	require MT::Entry;
		# two basic types of listing: grouped and non-grouped
	if ($group_by) {
		my %collected = ();
		for my $tag (@tags) {
			for my $instance (@{$col->{$tag}}) {
				next unless ($instance->{$group_by});
				$instance->{'_tag'} = $tag;
				push(@{$collected{$instance->{$group_by}}}, $instance);
			}
		}
		my @keys;
		if ($sort_by eq 'count') {
			if ($sort_order eq 'descend') {
				@keys = sort { scalar(@{$collected{$b}})
						<=> scalar(@{$collected{$a}}) }
						keys %collected;
			} else {
				@keys = sort { scalar(@{$collected{$a}})
						<=> scalar(@{$collected{$b}}) }
						keys %collected;
			}
		} else {
			if ($sort_order eq 'descend') {
				@keys = sort { $b cmp $a } keys %collected;
			} else {
				@keys = sort { $a cmp $b } keys %collected;
			}
		}
		my $index = 0;
			# loop through the groupings
		for my $key (@keys) {
				# when grouping by site, if site is blank (i.e. a relative URL), 
				# show_local="1" must be passed in order to show the grouping
			next if (!$key && ($group_by eq '_site') && !$args->{'show_local'});
			my $count = scalar(@{$collected{$key}});
			next if ($min_count && ($count < $min_count));
			my @entries = ();
			my %instances = ();
			my $item = {};
				# keep count of instances of each tag within this grouping
			$item->{'ns'} = {};
				# load the entries associated with this grouping
			for my $instance (@{$collected{$key}}) {
				$item->{'ns'}->{$instance->{'_tag'}}++;
				if (my $e_id = $instance->{'_entry_id'}) {
					unless ($instances{$e_id}) {
						push(@entries, MT::Entry->load($e_id));
					}
					push(@{$instances{$e_id}}, $instance);
				}
			}
				# stash entries so a nested MTEntries can access them
			local $ctx->{__stash}{'entries'};
			if (@entries) {
				$ctx->{__stash}{'entries'} = \@entries;
			}
			$item->{'group'} = $key;
			$item->{'count'} = $count;
			$item->{'index'} = ++$index;
			$item->{'instances'} = \%instances;
			local $ctx->{__stash}{'mtcollect_item'} = $item;
			defined(my $item_text = $builder->build($ctx, $tokens, $cond))
				|| return $ctx->error($ctx->errstr);
			$text .= $item_text;
			last if ($lastn && ($index == $lastn));
		}
	} else {
			# not grouping; displaying once for each collected tag instance
		my @collected = ();
		$sort_by ||= '_abs_n';
		my $skip_dupes = $args->{'skip_dupes'} ? 1 : 0;
		for my $tag (@tags) {
			for my $instance (@{$col->{$tag}}) {
				$instance->{'_tag'} = $tag;
				push(@collected, $instance);
			}
		}
		if ($sort_by eq '_abs_n') {
			if ($sort_order eq 'descend') {
				@collected = sort { $b->{$sort_by} <=> $a->{$sort_by} } @collected;
			} else {
				@collected = sort { $a->{$sort_by} <=> $b->{$sort_by} } @collected;
			}
		} else {
			if ($sort_by =~ /^content|site$/) {
				$sort_by = '_' . $sort_by;
			}
			if ($sort_order eq 'descend') {
				@collected = sort { $b->{$sort_by} cmp $a->{$sort_by} } @collected;
			} else {
				@collected = sort { $a->{$sort_by} cmp $b->{$sort_by} } @collected;
			}
		}
		my $count = scalar(@collected);
		my $index = 0;
		my $last_key;
		for my $instance (@collected) {
				# if an attribute is specified as a URL and this instance
				# doesn't have a site (i.e. a relative URL), show_local="1"
				# must be passed in order to show the instance
			next if (defined($instance->{'_site'}) &&
					!$instance->{'_site'} && !$args->{'show_local'});
				# skip duplicate key if skip_dupes was passed
			if ($sort_by ne '_abs_n') {
				next if ($skip_dupes && ($index > 0)
					&& ($instance->{$sort_by} eq $last_key));
				$last_key = $instance->{$sort_by};
			}
				# load the entry from which this instance was collected
			my @entries = ();
			local $ctx->{__stash}{'entries'};
			if (my $e_id = $instance->{'_entry_id'}) {
				$ctx->{__stash}{'entries'} = [ MT::Entry->load($e_id) ];
			}
			my $item = {};
			$item->{'instance'} = $instance;
			$item->{'count'} = $count;
			$item->{'index'} = ++$index;
			local $ctx->{__stash}{'mtcollect_item'} = $item;
			defined(my $item_text = $builder->build($ctx, $tokens, $cond))
				|| return $ctx->error($ctx->errstr);
			$text .= $item_text;
			last if ($lastn && ($index == $lastn));
				# keep track of previous key so we can skip duplicates
		}
	}
	return $text;
}

sub _hdlr_collected_archive {
	my ($ctx, $args, $cond) = @_;
	defined (my $item = $ctx->stash('mtcollect_item'))
		|| return $ctx->error('Not called from within MTCollected container');
	defined (my $instances = $item->{'instances'})
		|| return $ctx->error('Not called from within grouped MTCollected container');
	defined (my $template = $args->{'template'})
		|| return $ctx->error('No template specified');
	my $blog = $ctx->stash('blog');
		# get the specified template so we can use it to build the
		# archive pages
	require MT::Template;
	my $tmpl = MT::Template->load({ name => $template, blog_id => $blog->id })
		|| return $ctx->error("Can't find template '$template'");
	defined(my $text = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		|| return $ctx->error($ctx->errstr);
		# strip leading and trailing whitespace from contents
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return '' unless ($text);
	require MT::Template::Context;
	my $html = $tmpl->build($ctx)
		|| return $ctx->error("Error building template '$template': " . $tmpl->errstr);
		# create a file relative to the local archive path, whose filename is
		# the contents of this tag
	use File::Spec;
	my $fmgr = $blog->file_mgr;
	(my $arch_root = $blog->archive_path)
		|| return $ctx->error('You did not set your Local Archive Path');
	my $file = File::Spec->catfile($arch_root, $text);
	($file) = $file =~ /(.+)/s;
	if ($args->{'create_directories'}) {
		require File::Basename;
		my $path = File::Basename::dirname($file);
		$path =~ s!/$!!;
		unless ($fmgr->exists($path)) {
			$fmgr->mkpath($path)
				|| return $ctx->error("Error making path '$path': " . $fmgr->errstr);
		}
	}
	defined($fmgr->put_data($html, $file))
		|| return $ctx->error("Couldn't write '$file': " . $fmgr->errstr);
	if ($args->{'omit_filename'}) {
		$text = reverse $text;
		$text =~ s!(^[^/]+)!!;
		$text = reverse $text;
	}
    return $text;
	
}

sub _hdlr_collected_entry_tags {
	my ($ctx, $args, $cond) = @_;
	defined (my $params = $ctx->stash('mtcollect_params'))
		|| return $ctx->error('Not called from within MTCollect container');
	defined (my $item = $ctx->stash('mtcollect_item'))
		|| return $ctx->error('Not called from within MTCollect container');
	defined (my $instances = $item->{'instances'})
		|| return $ctx->error('Not called from within grouped MTCollected container');
	defined (my $e = $ctx->stash('entry'))
		|| return $ctx->_no_entry_error('MTCollectedEntryTags');
	my %tags = ();
	if (my $tags = $args->{'tags'}) {
		%tags = map { $_ => 1 } split(/,/, $tags);
	} else {
		%tags = %{$params->{'tags'}};
	}
	my $text = '';
	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
		# loop through collected tag instances belonging to this entry
	for my $instance (@{$instances->{$e->id}}) {
		next unless $tags{$instance->{'_tag'}};
		$item->{'instance'} = $instance;
		$ctx->stash('mtcollect_item', $item);
		defined(my $instance_text = $builder->build($ctx, $tokens, $cond))
			|| return $ctx->error($ctx->errstr);
		$text .= $instance_text;
	}
	return $text;
}

sub _hdlr_collected_group {
	return item_element('group', @_);
}

sub _hdlr_collected_total_count {
	my ($ctx, $args) = @_;
	defined (my $col = $ctx->stash('mtcollect_collection'))
		|| return $ctx->error('Not called from within MTCollect container');
	if (my $tags = $args->{'tags'}) {
		my $count = 0;
		for (split(/,/, $tags)) {
			$count += $col->{'ns'}->{$_};
		}
		return $count;
	} else {
		return $col->{'abs_n'};
	}
}

sub _hdlr_collected_group_count {
	my ($ctx, $args) = @_;
	defined (my $item = $ctx->stash('mtcollect_item'))
		|| return $ctx->error('Not called from within MTCollected container');
	if (my $tags = $args->{'tags'}) {
		my $count = 0;
		for (split(/,/, $tags)) {
			$count += $item->{'ns'}->{$_};
		}
		return $count;
	} else {
		return $item->{'count'};
	}
}

sub _hdlr_collected_index {
	return item_element('index', @_);
}

sub _hdlr_collected_tag {
	return instance_element('_tag', @_);
}

sub _hdlr_collected_content {
	return instance_element('_content', @_);
}

sub _hdlr_collected_site {
	return instance_element('_site', @_);
}

sub _hdlr_collected_attr {
	my ($ctx, $args) = @_;
	defined (my $attr = $args->{'attr'})
		|| return $ctx->error('No attribute passed');
	return instance_element($attr, $ctx);
}

sub _hdlr_if_collected_attr {
	return _hdlr_collected_attr(@_) ? 1 : 0;
}

sub _hdlr_if_collected_content {
	return _hdlr_collected_content(@_) ? 1 : 0;
}

sub _hdlr_if_collected_site {
	return _hdlr_collected_site(@_) ? 1 : 0;
}

sub item_element {
	my ($key, $ctx) = @_;
	defined (my $item = $ctx->stash('mtcollect_item'))
		|| return $ctx->error('Not called from within MTCollected container');
	return ($item->{$key} || '');
}

sub instance_element {
	my ($key, $ctx) = @_;
	defined (my $item = $ctx->stash('mtcollect_item'))
		|| return $ctx->error('Not called from within MTCollected container');
	defined (my $instance = $item->{'instance'})
		|| return $ctx->error('Not called from within MTCollectedEntryTags or non-grouped MTCollected container');
	return ($instance->{$key} || '');
}

sub collect_tag {
	my ($params, $col, $original, $tag, $attrs, $content, $n, $abs_n, 
		$replace, $entry_id) = @_;
		# format string (see documentation)
	$replace ||= '';
	my ($open, $close) = split(m#(?<!\\)/#, $replace);
	for ($open, $close) {
		$_ ||= '';
		$_ =~ s#\\/#/#g;
		$_ = decode_html($_);
			# make sure slashes get decoded even without HTML::Entities
		$_ =~ s!&#47;!/!g;
	}
	my %tag_attrs = ();
	while ($attrs =~ /(\w+)\s*=\s*(["'])(.*?)\2/gs) {
		$tag_attrs{$1} = $3;
	}
	for (%tag_attrs) {
		if ($params->{'urls'}->{$_}) {
			$tag_attrs{'_site'} = site_from_url($tag_attrs{$_});
		}
	}
	$tag_attrs{'_content'} = $content;
	$tag_attrs{'_n'} = $n;
	$tag_attrs{'_abs_n'} = $abs_n;
	$tag_attrs{'_entry_id'} = $entry_id if ($entry_id);
		# deal with attributes within the formatting string
	for my $str ($open, $close) {
		next unless $str;
		if ($str =~ /[\[\]]/) {
			$str =~ s/(?<!\\)\[/</g;
			$str =~ s/(?<!\\)\]/>/g;
				# de-escape escaped []
			$str =~ s/\\\[/[/g;
			$str =~ s/\\\]/]/g;
		}
		for (keys %tag_attrs) {
			$str =~ s/<$_>/$tag_attrs{$_}/ig;
		}
		$str =~ s/<N>/$n/ig;
	}
	push(@{$col->{$tag}}, \%tag_attrs);
	return $open . $original . $close;
}

sub site_from_url {
# "site" = machine name, but ignoring leading 'www'
	my ($url) = @_;
	return '' unless $url;
	my $site = '';
	if ($url =~ m!^http://([^/:]+)!i) {
		$site = lc($1);
	}
	$site =~ s/^www\.//;
	return $site;
}

1;
