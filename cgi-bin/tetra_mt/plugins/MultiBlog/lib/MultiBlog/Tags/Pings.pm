
package MultiBlog::Tags::Pings;

sub pings {
    my($ctx, $args, $cond) = @_;
    require MT::Entry;
    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;

	my @blog_ids = &MT::Plugin::MultiBlog::_include_blogs($ctx, $args);
	my (%args, %terms);
	$terms{ blog_id } = [ @blog_ids ];

    my $so = $args->{sort_order} || 'descend';
	my $n = $args->{lastn};
	my $reverse = $n && $so eq 'ascend';
	my %loadargs = ( 'sort' => 'created_on', direction => $reverse ? 'descend' : $so );
	my $offset = $args->{offset} || 0;

	$loadargs{ limit } = $n if $n;
	$loadargs{ offset } = $offset if $offset;

	## Add range if inside of date archive
	if($ctx->{current_timestamp} && $ctx->{current_timestamp_end}) {
		$terms{created_on} = [ $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ];
		$loadargs{range} = { created_on => 1 };
	}

	my @pings = MT::TBPing->load(\%terms, \%loadargs);

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
    }
    $html;
}

1;
