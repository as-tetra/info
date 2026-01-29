
package MultiBlog::Tags::Comments;

sub comments {
    my($ctx, $args, $cond) = @_;
    require MT::Entry;
    my $blog_id = $ctx->stash('blog_id');
	local $ctx->{__stash}{local_blog_id} = $blog_id;

	my ($last, $limit_blogs);

	my @blog_ids = &MT::Plugin::MultiBlog::_include_blogs($ctx, $args);
	my %blog_id_hash = map { $_ => 1 } @blog_ids;
	$limit_blogs = %blog_id_hash ? scalar(keys(%blog_id_hash)) : 0;
	my (%args, %terms);
	$terms{ blog_id } = [ @blog_ids ];
	$terms{visible} = 1;

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

	my @comments = MT::Comment->load(\%terms, \%loadargs);

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
		last if $n && $i > $n;
    }
    $html;
}

1;
