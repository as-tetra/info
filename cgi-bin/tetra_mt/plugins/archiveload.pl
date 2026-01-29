# archiveload.pl -- Archive entry-loading plugin by Lummox JR
#
# This plugin is to avoid using an MT hack to load all entries for a
# date-based archive in version 2.64. Without it, <MTEntries> and
# <MTArchiveCount> will only work directly within <MTArchiveList>, not within
# a previous/next context which only loads 1 entry. <MTArchiveLoad> will load
# all of the entries from the time period, making those tags workable again.
# (This will also help in the ArchiveYear plugin.)

package LummoxJR::archiveload;

use MT::Template::Context;

MT::Template::Context->add_container_tag(ArchiveLoad => \&archive_load);

sub archive_load {
	my($ctx, $args, $cond) = @_;
	my ($ts,$end) = ($ctx->{current_timestamp},$ctx->{current_timestamp_end});
	return $ctx->error(MT->translate(
			"You used an [_1] without an archive context set up.",
			"<MTArchiveLoad>" ))
		unless $ts && $end;
	my $res = '';
	my $builder = $ctx->stash('builder');
	my @entries = MT::Entry->load({blog_id => $ctx->stash('blog_id'),
	                               created_on => [$ts, $end],
	                               status => MT::Entry::RELEASE()},
	                              {range => {created_on => 1}});
	local $ctx->{__stash}->{entries} = \@entries;
	defined(my $out = $builder->build($ctx, $ctx->stash('tokens'), $cond))
		or return $ctx->error( $builder->errstr );
	$res .= $out;
	$res;
}
1;