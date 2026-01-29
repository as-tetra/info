
package MultiBlog::Tags::MultiBlog;


sub multiblog {
  my ($ctx, $args, $cond) = @_;

  my $blog_id = $ctx->stash ('blog_id');
  local $ctx->{__stash}{local_blog_id} = $blog_id;
  my @blog_ids = &MT::Plugin::MultiBlog::_include_blogs ($ctx, $args);

  my $builder = $ctx->stash ('builder');
  my $tokens  = $ctx->stash ('tokens');
  my $res = "";

# We're switching blogs, so there is no need to keep the entries stash and any
# archive date ranges around.
# And since we're using local, it'll come back once we leave the method.
  local $ctx->{__stash}{entries} = undef 
      if ($args->{ ignore_archive_context });
  local $ctx->{current_timestamp} = undef 
      if ($args->{ ignore_archive_context });
  local $ctx->{current_timestamp_end} = undef 
      if ($args->{ ignore_archive_context });

# Same with categories
  local $ctx->{__stash}{category} = undef 
      if ($args->{ ignore_archive_context });;
  local $ctx->{__stash}{archive_category} = undef 
      if ($args->{ ignore_archive_context });

  require MT::Blog;
  foreach my $blog_id (@blog_ids) {
    my $blog = MT::Blog->load ($blog_id) or next;
    local $ctx->{__stash}{blog} = $blog;
    local $ctx->{__stash}{blog_id} = $blog->id;

    defined (my $out = $builder->build ($ctx, $tokens, $cond))
      or return $ctx->error ($builder->errstr);
    $res .= $out;
  }

  $res;
}

1;
