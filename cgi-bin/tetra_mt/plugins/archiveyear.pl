# ArchiveYear plugin for Movable Type, by Lummox JR
# Version 1.2

package LummoxJR::archiveyear;

use MT::Template::Context;
use MT::Util qw( start_end_day start_end_week start_end_month
	html_text_transform munge_comment archive_file_for
	format_ts offset_time_list first_n_words dirify get_entry
	encode_html encode_js remove_html wday_from_ts days_in
	spam_protect encode_php encode_url decode_html encode_xml );

MT::Template::Context->add_container_tag(ArchiveYearPrevious => \&archive_year_prev_next);
MT::Template::Context->add_container_tag(ArchiveYearNext => \&archive_year_prev_next);
MT::Template::Context->add_container_tag(ArchiveYear => \&archive_year);
MT::Template::Context->add_conditional_tag(ArchiveYearRowHeader => \&archive_year_condition);
MT::Template::Context->add_conditional_tag(ArchiveYearRowFooter => \&archive_year_condition);
MT::Template::Context->add_conditional_tag(ArchiveYearIfEntries => \&archive_year_condition);
MT::Template::Context->add_conditional_tag(ArchiveYearIfNoEntries => \&archive_year_condition);
MT::Template::Context->add_conditional_tag(ArchiveYearIfBlank => \&archive_year_condition);
MT::Template::Context->add_conditional_tag(ArchiveYearIfNotBlank => \&archive_year_condition);
MT::Template::Context->add_tag(ArchiveYearCount => \&archive_year_count);

sub archive_year_prev_next {
	my($ctx, $args, $cond) = @_;
	my $tag = $ctx->stash('tag');
	my $is_prev = $tag eq 'ArchiveYearPrevious';
	my $ts = $ctx->{current_timestamp};
	if(!$ts) {
		my @TS = offset_time_list(time, $ctx->stash('blog_id'));
		$ts = sprintf "%04d%02d%02d%02d%02d%02d", $TS[5]+1900, $TS[4]+1, @TS[3,2,1,0];
		}
	my $res = '';
	my $year = unpack 'A4', $ts;
	if($is_prev) {$ts=sprintf "%04d0101000000", $year;}
	else {$ts=sprintf "%04d1231235959", $year;}
	my @arg = ($ts, $ctx->stash('blog_id'), 'Monthly');
	push @arg, $is_prev ? 'previous' : 'next';
	if (my $entry = get_entry(@arg)) {
		my $builder = $ctx->stash('builder');
		local $ctx->{__stash}->{entries} = [ $entry ];
		my($start, $end) = start_end_month($entry->created_on);
		local $ctx->{current_timestamp} = $start;
		local $ctx->{current_timestamp_end} = $end;
		defined(my $out = $builder->build($ctx, $ctx->stash('tokens'),
			$cond))
			or return $ctx->error( $builder->errstr );
		$res .= $out;
	}
	$res;
}

sub archive_year {
	my($ctx, $args, $cond) = @_;

	my($ts,$year);
	my @TS = offset_time_list(time, $blog_id);
	my $today = $TS[5]+1900;
	if($year=$args->{year}) {
		return $ctx->error(MT->translate(
			"Invalid month format: must be YYYY" ))
			unless length($year) eq 4;
		}
	elsif(defined $ctx->{current_timestamp}) {$year = unpack 'A4', $ctx->{current_timestamp}}
	else {$year = $today}
	my $res = '';

	my $order = $args->{order};
	if(!$order) {$order='ascend';}
	return $ctx->error(MT->translate(
	  "order=\"[_1]\" is not valid in [_2].", $order, "<MTArchiveYear>" ))
	  unless $order eq 'ascend' || $order eq 'descend';
	my $columns=$args->{columns};
	if(!$columns) {$columns=3;}
	my $skip = $args->{skip};
	my $soy=sprintf "%04d1231235959",($year-1);
	my $eoy=sprintf "%04d0101000000",($year+1);

	my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('tokens');
	local $ctx->{current_timestamp} = sprintf "%04d0101000000", $year;

	my @arg=((($order eq 'descend')?$eoy:$soy), $ctx->stash('blog_id'), 'Monthly', ($order eq 'descend')?'previous':'next');
	my @months=();
	foreach(1..12) {push @months, sprintf "%04d%02d",$year,$_;}
	@months = reverse @months if $order eq 'descend';
	my $col=0;
	my $cells=0;
	my $firstentry = MT::Entry->load(
		{ blog_id => $ctx->stash('blog_id'),
		  status => MT::Entry::RELEASE() },
		{ limit => 1,
		  'sort' => 'created_on',
		  direction => $order });
	my $entry = $firstentry;
	if($firstentry && ($year != unpack 'A4',$firstentry->created_on)) {
		$cells=1;
		$entry=get_entry(@arg);
		}
	my $ltime="000000";
	$ltime = substr $entry->created_on, 0, 6 if $entry;

	my @skipped=();
	while(my $mon=shift @months) {
		push @skipped, $mon;
		my $thismonth=$entry && $ltime==$mon;
		if(!$skip || $col || $thismonth || ($entry && $cells)) {
			while($mon=shift @skipped) {
				++$col;
				my($start, $end) = start_end_month($mon);
				local $ctx->{current_timestamp} = $start;
				local $ctx->{current_timestamp_end} = $end;
				defined(my $out = $builder->build($ctx, $tokens, {
					%$cond,
					ArchiveYearRowHeader => $col <= 1,
					ArchiveYearRowFooter => $col >= $columns,
					ArchiveYearIfEntries => $mon==$ltime,
					ArchiveYearIfNoEntries => $mon!=$ltime && (!$skip || ($entry && $cells)),
					ArchiveYearIfBlank => $mon!=$ltime && $skip && (!$entry || !$cells),
				})) or
					return $ctx->error( $builder->errstr );
				$res .= $out;
				$col%=$columns;
				++$cells if $mon==$ltime;
				}
			}
		elsif($skip && !$cells && (scalar @skipped)==$columns) {@skipped=();}
		if($thismonth) {
			$arg[0]=$entry->created_on;
			$entry = get_entry(@arg);
			$ltime = substr $entry->created_on, 0, 6 if $entry;
			}
		}
	# finish last row if necessary
	while($col && $col<$columns) {
		++$col;
		defined(my $out = $builder->build($ctx, $tokens, {
			%$cond,
			ArchiveYearRowFooter => $col >= $columns,
			ArchiveYearIfBlank => 1,
		})) or
			return $ctx->error( $builder->errstr );
		$res .= $out;
		}

	$res;
	}

sub archive_year_condition {
	my($ctx, $args, $cond) = @_;
	my $tag=$ctx->stash('tag');
	return !($cond->{$tag}) if($tag =~ s/IfNot/If/);
	$cond->{$tag};
	}

sub archive_year_count {
	my ($ctx,$args)=@_;
	my($ts,$year);
	my @TS = offset_time_list(time, $blog_id);
	my $today = $TS[5]+1900;
	if($year=$args->{year}) {
		return $ctx->error(MT->translate(
			"Invalid month format: must be YYYY" ))
			unless length($year) eq 4;
		}
	elsif(defined $ctx->{current_timestamp}) {$year = unpack 'A4', $ctx->{current_timestamp}}
	else {$year = $today}
	# NOTE: This may screw up on blogs using Berkeley DB that have had post
	# dates changed to other years and back again. It's a Movable Type bug.
	require MT::Entry;
	scalar MT::Entry->count({ blog_id => $ctx->stash('blog_id'),
	                          created_on => [(sprintf "%04d0101000000", $year), (sprintf "%04d1231235959", $year)],
	                          status => MT::Entry::RELEASE() },
	                        { range => {created_on => 1}});
}
