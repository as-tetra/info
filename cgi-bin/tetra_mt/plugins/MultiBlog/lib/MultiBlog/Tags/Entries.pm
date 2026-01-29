
package MultiBlog::Tags::Entries;

use strict;
use warnings;

use MT::Util qw( start_end_day start_end_week start_end_month
                 html_text_transform munge_comment archive_file_for
                 format_ts offset_time_list first_n_words dirify get_entry
                 encode_html encode_js remove_html wday_from_ts days_in
                 spam_protect encode_php encode_url decode_html encode_xml
                 decode_xml );

sub entries {
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
    my ($last, $offset);
    my @blog_ids = &MT::Plugin::MultiBlog::_include_blogs($ctx, $args);
    if (%$args) {
        my %terms = ( status => MT::Entry::RELEASE() );
        $terms{author_id} = $author->id if $author;

        my %args;
        $terms{ blog_id } = [ @blog_ids ];
        if ($cat) {
            require MT::Placement;
            $args{'join'} = [ 'MT::Placement', 'entry_id',
                { category_id => $cat->id }, { unique => 1 } ];
        }
        $offset = $args->{offset} || 0;
        my %offsets = ();
        if ($args->{offset_local_only}) {
            $offsets{$blog_id} = $offset;
            undef $offset;
        } elsif ($args->{offset_blogs}) {
            $offsets{$_} = $offset foreach (split (",", $args->{offset_blogs}));
            undef $offset;
        } elsif ($args->{offset_all_blogs}) {
            $offsets{$_} = $offset foreach (@blog_ids);
            undef $offset;
        }
        my %lastns = ();
        if ($last = $args->{lastn}) {
            $args{'sort'} = 'created_on';
            $args{direction} = $args->{sort_order} ? $args->{sort_order} : 'descend';
        } elsif ($last = $args->{lastn_per_blog}) {
            $args{'sort'} = 'created_on';
            $args{'direction'} = 'descend';
            $lastns{$_} = $last foreach (@blog_ids);
            undef $last;
        } elsif ($last = $args->{lastn_modified}) {
            $args{'sort'} = 'modified_on';
            $args{direction} = 'descend';
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

        my %categories;
        my $limit_categories;
        my $cat_filter;
        if (my $cat_label = $args->{category}) {
            require MT::Category;
            require MT::Template::ContextHandlers;
            
            my @cats = MT::Category->load ({ blog_id => \@blog_ids });
            my $cat_cexpr = MT::Template::Context::_compile_category_filter ($cat_label, \@cats, 
                { children => $args->{include_subcategories} ? 1 : 0 });
            
            if ($cat_cexpr) {
                my %map;
                require MT::Placement;
                for my $cat (@cats) {
                    my $iter = MT::Placement->load_iter({ category_id => $cat->id });
                    while (my $p = $iter->()) {
                        $map{$p->entry_id}{$cat->id}++;
                    }
                }
                
                $cat_filter = sub { $cat_cexpr->($_[0]->id, \%map) };
            }
        }


## Add range if inside of date archive
        if($ctx->{current_timestamp} && $ctx->{current_timestamp_end}) {
            $terms{created_on} = [ $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ];
            $args{range} = { created_on => 1 };
        }

## Load entries

        @entries = grep { 
            (!$cat_filter || $cat_filter->($_)) &&
                (!defined $offsets{$_->blog_id} || $offsets{$_->blog_id}-- <= 0) &&
                (!defined $offset               || $offset-- <= 0) && 
                (!defined $lastns{$_->blog_id}  || $lastns{$_->blog_id}-- > 0) &&
                (!defined $last                 || $last-- > 0)
        } MT::Entry->load (\%terms, \%args);

    } else {
        my $days = $ctx->stash('blog')->days_on_index;
        my @ago = offset_time_list(time - 3600 * 24 * $days,
                $ctx->stash('blog_id'));
        my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
           $ago[5]+1900, $ago[4]+1, @ago[3,2,1,0];
        @entries = MT::Entry->load({ 
                status => MT::Entry::RELEASE(),
                blog_id => [ @blog_ids ],
                },
                { range => { created_on => 1 } });
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
    my $last_blog_id = 0;
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
                MultiBlogBlogHeader => $last_blog_id != $blog->id,
                MultiBlogBlogFooter => !defined $entries[$i+1] || $entries[$i+1]->blog_id != $blog->id,
                });
        MT::ConfigMgr->instance->NoPlacementCache($noPlacementCache);
        $last_day = $this_day;
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
        $i++;
        $last_blog_id = $blog->id;
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

1;
