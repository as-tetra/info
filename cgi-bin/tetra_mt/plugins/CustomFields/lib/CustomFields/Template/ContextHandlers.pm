# CustomFields
# By Arvind Satyanarayan 
# http://www.movalog.com/ 
# ---------------------------------------------------------------------------
# Based on
# Authors
# A Plugin for Movable Type
#
# Release 1.32
# October 11, 2002
#
# From Brad Choate
# http://www.bradchoate.com/
# ---------------------------------------------------------------------------
# This software is provided as-is.
# You may use it for commercial or personal use.
# If you distribute it, please keep this notice intact.
#
# Copyright (c) 2002 Brad Choate
# ---------------------------------------------------------------------------

package CustomFields::Template::ContextHandlers;

use strict;
use MT::Util qw(spam_protect format_ts);
use CustomFields::Util qw( find_customfield get_customfields );

sub _hdlr_authors {
    my ($plugin, $ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');

	if($args->{sort_by} =~ m/^CUSTOMFIELD:(.*)/) {
	    unshift @$tokens, ['CustomFieldsResort', {'sort_by' => $1, 'sort_order' => $args->{sort_order}, 'datasource' => 'author'}, undef, undef, [ ['sort_by', $1], ['sort_order', $args->{sort_order}], ['datasource', 'author'] ] ];
		$args->{sort_by} = $args->{sort_order} = '';
	}
	
    my ($res, @perms, @authors, $terms);

   	my @blog_ids = split /,/, $args->{include_blogs} || ($ctx->stash('blog_id'));
    my $entry_sort = $args->{entry_sort};
    my $entry_dir = $args->{entry_direction};
	my $show_typekey = $args->{show_commenters} || 0;
	
	my $col = $args->{sort_by} || 'name';
	my $so = $args->{sort_order} || 'ascend';
	
	$args->{id} ? $terms->{id} = $args->{id} : '';
	
	$args->{permissions} ? @perms = split /,/, $args->{permissions} : '';

    my $needs_entries = ($ctx->stash('uncompiled') =~ /<\$?MTEntries/) ? 1 : 0;

	local $ctx->{__stash}{authors};
    local $ctx->{__stash}{entries} = $ctx->{__stash}{entries};
    local $ctx->{__stash}{author_entries} = $ctx->{__stash}{author_entries};

	require MT::Author;
	require MT::Entry;
    my $iter = MT::Author->load_iter($terms,{'sort' => 'name'});

    while (my $author = $iter->()) {
    	next if $author->type == 2 && !$show_typekey;

		my (@entries, $has_blog_perms);

		foreach my $blog_id (@blog_ids) {
			my $perms = MT::Permission->load({ blog_id => $blog_id, author_id => $author->id });
			next if !$perms;
			$has_blog_perms = 1;
			my $has_perms = 1;
			foreach (@perms) {
			    my $perm = 'can_'.$_;
			    if (!$perms->$perm()) {
					$has_perms = 0;
					last;
			    }
			}
			next if !$has_perms;
			
			if ($needs_entries || $col eq 'entrycount') {
	 			foreach my $blog_id (@blog_ids) {
					my @e = MT::Entry->load({ blog_id => $blog_id,
		                                      status => MT::Entry::RELEASE(),
							                  author_id => $author->id },
		                                    { 'sort' => $entry_sort || 'created_on',
		                                      direction => $entry_dir || 'descend' });
					push @entries, @e;
				}
	        }
									
		}
		next unless $has_blog_perms;
		
		$author->{entries} = \@entries;
		$author->{entrycount} = scalar(@entries);
		
		push @authors, $author;
	}
	
	if($col eq 'entrycount') {
		@authors = $so eq 'ascend' ?
	        sort { $a->{$col} <=> $b->{$col} } @authors :
	        sort { $b->{$col} <=> $a->{$col} } @authors;		
	} else {
		@authors = $so eq 'ascend' ?
	        sort { $a->$col() cmp $b->$col() } @authors :
	        sort { $b->$col() cmp $a->$col() } @authors;
	}
	
	local $ctx->{__stash}{authors} = \@authors;

	my $counter = 0;
	foreach my $author (@authors) {
		$counter++;
		last if defined $args->{limit} && $counter > $args->{limit};
		local $ctx->{__stash}{author} = $author;
		$ctx->{__stash}{entries} = $author->{entries};
		$ctx->{__stash}{author_entries} = $author->{entries};
	    my $out = $builder->build($ctx, $tokens, {
            %$cond,
            AuthorsHeader => ($counter == 1),
            AuthorsFooter => !(defined $authors[$counter+1]),
        });
		return $ctx->error($builder->errstr) unless defined $out;
		$res .= $out;		
	} 

    $res;
}

sub _hdlr_author_id {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    $a ? $a->id || '' : '';
}

sub _hdlr_author_name {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    $a ? $a->name || '' : '';
}

sub _hdlr_author_nickname {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    $a ? $a->nickname || '' : '';
}

sub _hdlr_author_email {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    return '' unless $a && defined $a->email;
    $_[2] && $_[2]->{'spam_protect'} ? spam_protect($a->email) : $a->email;
}

sub _hdlr_author_url {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    $a ? $a->url || '' : '';
}

sub _hdlr_author_link {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    return '' unless $a;
    my $name = $a->name || '';
    if ($a->url) {
        return sprintf qq(<a target="_blank" href="%s">%s</a>), $a->url, $name;
    } elsif ($a->email) {
        my $str = "mailto:" . $a->email;
        $str = spam_protect($str) if $_[2] && $_[2]->{'spam_protect'};
        return sprintf qq(<a href="%s">%s</a>), $str, $name;
    } else {
        return $name;
    }
}

sub _hdlr_author_public_key {
    my $a = $_[1]->stash('author');
    my $e = $_[1]->stash('entry');
    $a = $e->author if !$a && $e;
    $a ? $a->public_key || '' : '';
}

sub _hdlr_author_blog_count {
    my ($plugin, $ctx, $args) = @_;
    my $a = $ctx->stash('author');
    my $e = $ctx->stash('entry');
    $a = $e->author if !$a && $e;
	require MT::Blog;
    my $iter = MT::Blog->load_iter();
    my $count = 0;
	require MT::Permission;
    while ($b = $iter->()) {
		my $perms = MT::Permission->load({ blog_id => $b->id, author_id => $a->id });
		$count++ if $perms;
    }
    $count;
}

sub _hdlr_author_entry_count {
    my ($plugin, $ctx, $args) = @_;
    my $a = $ctx->stash('author');
    my $e = $ctx->stash('entry');
    $a = $e->author if !$a && $e;
    my $blog_id = $ctx->stash('blog_id');
    my $entries = $ctx->stash('author_entries');

	return scalar(@$entries) if $entries;

	require MT::Entry;
    my @entries = MT::Entry->load({ blog_id => $blog_id,
				    status => MT::Entry::RELEASE(),
				    author_id => $a->id});
    scalar(@entries);
}

sub _hdlr_customfield_obj {
	my ($plugin, $ctx, $args, $datasource) = @_;
	if($datasource eq 'category') {
		return $ctx->stash('category') || $ctx->stash('archive_category');
	} elsif($datasource eq 'author') {
		return $ctx->stash('author') || $ctx->stash('entry')->author;
	} else {
		return $ctx->stash($datasource);
	}	
}

sub _hdlr_customfield_data {
    my ($plugin, $ctx, $args, $cond, $datasource) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $res = '';	
	my @fields;
	my $blog_id = $ctx->stash('blog_id');

	if($args->{'field'}) {
		my $field = find_customfield($plugin, { name => $args->{'field'}, field_datasource => $datasource, blog_id => $blog_id });
		push @fields, $field;
	} else {
		@fields = @{ get_customfields($plugin, { field_datasource => $datasource, blog_id => $blog_id}, 1) };
	}

    my $exclude_field = $args->{exclude};

	foreach my $field (@fields) {
		next unless $field;
		next if $field->name eq $exclude_field;
		$ctx->stash('customfield', $field);
		defined(my $out = $builder->build($ctx, $tokens))
            or return $ctx->error($builder->errstr);
        $res .= $out;
	}
	 $res;
}

sub _hdlr_customfield_data_field_name {
    my ($plugin, $ctx, $args) = @_;
    my $field = $ctx->stash('customfield');
	return $field->name;
}

sub _hdlr_customfield_data_field_description {
    my ($plugin, $ctx, $args) = @_;
    my $field = $ctx->stash('customfield');
	return $field->description;	
}

sub _hdlr_customfield_data_field_value {
    my ($plugin, $ctx, $args, $cond, $datasource) = @_;
	my $field = $ctx->stash('customfield');
	my $field_id = $field->id; 
	my $field_type = $field->type;

	my $obj = &_hdlr_customfield_obj($plugin, $ctx, $args, $datasource);
	my $id = $obj->id;

	my $data = $ctx->stash("customfield_data_${datasource}_${id}");
	if(!$data) {		
		require MT::PluginData;
		$data = MT::PluginData->load({ plugin => 'CustomFields', key => "${datasource}_${id}"});
		(defined $data) ? $ctx->stash("customfield_data_${datasource}_${id}", $data) : undef;
	}

	my $res = '';

	if($data) {
		if($data->data->{$field_id}) {
			my $value = $data->data->{$field_id};
			if($field_type eq 'textarea') {
			    my $convert_breaks = exists $args->{convert_breaks} ?
			        $args->{convert_breaks} :
			            ($datasource eq 'entry' && defined $obj->convert_breaks) ? $obj->convert_breaks :
			                $ctx->stash('blog')->convert_paras;
				if($convert_breaks) {
					$convert_breaks = '__default__' if $convert_breaks eq '1';
					$value = MT->apply_text_filters($value, [ $convert_breaks ], $ctx);
				}
			} elsif($field_type eq 'date') {
				$value =~ s/\W//g;			
				if(length $value == 8) {
					$value .= '000000'
				}
				$args->{ts} = $value;
				$ctx->_hdlr_date($args);
			}
			$res = $value;
		}
	}
	
	$res;
}

sub _hdlr_customfield_resort {
	my ($plugin, $ctx, $args, $cond) = @_;
	return '' unless $cond->{EntriesHeader} || $cond->{AuthorsHeader} || $cond->{CategoriesHeader};
	
	my $datasource = $args->{datasource};
	my $sort_by = $args->{sort_by};
	my $blog_id = $ctx->stash('blog_id') || $ctx->stash('blog')->id;
	
	my $objs;
	if($datasource eq 'entry') {
		$objs = $ctx->stash('entries');
	} elsif($datasource eq 'author') {
		$objs = $ctx->stash('authors');
	} elsif($datasource eq 'category') {
		$objs = $ctx->stash('categories');
	}

	my $field = find_customfield($plugin, { name => $sort_by, field_datasource => $datasource, blog_id => $blog_id });
	
	return '' unless $field;
	
	my $field_id = $field->id;
	require MT::PluginData;
	foreach my $obj (@$objs) {
		my $id = $obj->id;
		my $data = $ctx->stash("customfield_data_${datasource}_${id}");
		if(!$data) {		
			$data = MT::PluginData->load({ plugin => 'CustomFields', key => "${datasource}_${id}"});
			(defined $data) ? $ctx->stash("customfield_data_${datasource}_${id}", $data) : undef;
		}
		$obj->{$field_id} = $data ? $data->data->{$field_id} : '';
	}
	
    @$objs = $args->{sort_order} eq 'ascend' ?
        sort { uc($a->{$field_id}) cmp uc($b->{$field_id}) } @$objs :
        sort { uc($b->{$field_id}) cmp uc($a->{$field_id}) } @$objs;
	
	$ctx->stash($datasource, @$objs[0]);
	
	if($datasource eq 'author') {
		$ctx->stash('entries', @$objs[0]->{entries});
		$ctx->stash('author_entries', @$objs[0]->{entries});
	}
	
	return '';
}

sub _hdlr_entries {
	my($plugin, $ctx, $args, $cond) = @_;
	
	my $hdlr_entries_method = $plugin->{_hdlr_entries_method};
	my $sort_by = $args->{sort_by};
	
	return &{$hdlr_entries_method}($ctx, $args, $cond) unless $sort_by =~ m/^CUSTOMFIELD:(.*)/;
	

    my @tokens = @{ $ctx->stash('tokens') };
    unshift @tokens, ['CustomFieldsResort', {'sort_by' => $1, 'sort_order' => $args->{sort_order}, 'datasource' => 'entry'}, undef, undef, [ ['sort_by', $1], ['sort_order', $args->{sort_order}], ['datasource', 'entry'] ] ];
    local $ctx->{__stash}{tokens} = \@tokens;

	$args->{sort_by} = $args->{sort_order} = '';

	&{$hdlr_entries_method}($ctx, $args, $cond);	
}

sub _hdlr_categories {
    my($plugin, $ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id');
	require MT::Category;
    require MT::Placement;
    my @categories = MT::Category->load({ blog_id => $blog_id },
        { 'sort' => 'label', direction => 'ascend' });
    my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');

	if($args->{sort_by} =~ m/^CUSTOMFIELD:(.*)/) {
	    unshift @$tokens, ['CustomFieldsResort', {'sort_by' => $1, 'sort_order' => $args->{sort_order}, 'datasource' => 'category'}, undef, undef, [ ['sort_by', $1], ['sort_order', $args->{sort_order}], ['datasource', 'category'] ] ];
		$args->{sort_by} = $args->{sort_order} = '';
	}

    my $glue = exists $args->{glue} ? $args->{glue} : '';
    ## In order for this handler to double as the handler for
    ## <MTArchiveList archive_type="Category">, it needs to support
    ## the <$MTArchiveLink$> and <$MTArchiveTitle$> tags
    local $ctx->{inside_mt_categories} = 1;
	local $ctx->{__stash}{categories} = \@categories; 
	my $i = 0;
    foreach my $cat (@categories) {
        local $ctx->{__stash}{category} = $cat;
        local $ctx->{__stash}{entries};
        local $ctx->{__stash}{category_count};
        my @args = (
            { blog_id => $blog_id,
              status => MT::Entry::RELEASE() },
            { 'join' => [ 'MT::Placement', 'entry_id',
                          { category_id => $cat->id } ],
              'sort' => 'created_on',
              direction => 'descend', });
        $ctx->{__stash}{category_count} = MT::Entry->count(@args);
        next unless $ctx->{__stash}{category_count} || $args->{show_empty};
        my $out = $builder->build($ctx, $tokens, {
            CategoriesHeader => !$i,
            CategoriesFooter => !defined $categories[$i+1],
        });

        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $glue if $res ne '';
        $res .= $out;
		$i++;
    }
    $res;
}

sub _builder_build {
	my ($plugin, $build, $ctx, $tokens, $cond) = @_;
	
	my $builder_build_method = $plugin->{builder_build_method};
	my $cf_populated = $plugin->{cf_populated};
	
	my $blog_id = $ctx->stash('blog_id') || $ctx->stash('blog')->id;
	my (@fields, @temp_fields);
	
	require CustomFields::CustomField;
	unless($cf_populated->{0}) {
		@temp_fields = CustomFields::CustomField->load({ blog_id => 0 });
		push @fields, @temp_fields;	
		$cf_populated->{0} = 1;
	}

	unless($cf_populated->{$blog_id}) {
		@temp_fields = CustomFields::CustomField->load({ blog_id => $blog_id });
		push @fields, @temp_fields;	
		$cf_populated->{$blog_id} = 1;	
	}
	
	foreach my $field (@fields) {
		my $tag = $field->tag;
		next if !$tag;

		$MT::Template::Context::Handlers{$tag} = sub { 
			my ($ctx, $args, $cond) = @_;
			$ctx->stash('customfield', $field); 
			
			&_hdlr_customfield_data_field_value($plugin, $ctx, $args, $cond, $field->field_datasource); 
		};	
		
	}
	
	&{$builder_build_method}($build, $ctx, $tokens, $cond);
}

1;