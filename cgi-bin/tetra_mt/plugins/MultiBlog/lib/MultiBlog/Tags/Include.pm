
package MultiBlog::Tags::Include;

sub include {
  my ($ctx, $args, $cond) = @_;

  my $blog_id = $ctx->stash('blog_id');
  local $ctx->{__stash}{local_blog_id} = $blog_id;

  my @blog_ids = &MT::Plugin::MultiBlog::_include_blogs($ctx, $args);

  my $default_blog_id = $args->{'default_blog'};
  my $module = $args->{'module'};

  return $ctx->error ("Can't access default blog") if (!grep {$_ == $default_blog_id} @blog_ids);

  require MT::Template;
  my $out;
  if (MT::Template->load ({ blog_id => $blog_id, name => $module })) {
    $out = &MT::Template::Context::_hdlr_include ($ctx, { module => $module }, $cond);
  } else {
    require MT::Blog;
    local $ctx->{__stash}{blog_id} = $default_blog_id;
    local $ctx->{__stash}{blog} = MT::Blog->load ($default_blog_id);
    $out = &MT::Template::Context::_hdlr_include ($ctx, { module => $module}, $cond );
  }
  $ctx->stash ('blog_id', $blog_id);
  $out;
}

1;
