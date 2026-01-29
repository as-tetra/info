
package MultiBlog::Tags::Categories;

sub categories {
    my($ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;
    
	my @blog_ids = &MT::Plugin::MultiBlog::_include_blogs($ctx, $args);

    require MT::Category;
    require MT::Placement;
    my $iter = MT::Category->load_iter( { blog_id => [ @blog_ids ] },
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

1;
