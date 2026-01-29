#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;
our $SYS;

# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

my %FORM = &form("noexchange");
my @DATA = &openfile2array("$SYS->{data_dir}hist.cgi");

my @BACKDATA;
foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	$row->{id} = $d[0];
	$row->{start_send_date} = substr($d[1], 0, 4)."/".substr($d[1], 4, 2)."/".substr($d[1], 6, 2)." ".substr($d[1], 8, 2).":".substr($d[1], 10, 2).":".substr($d[1], 12, 2);
	$row->{end_send_date} = substr($d[2], 0, 4)."/".substr($d[2], 4, 2)."/".substr($d[2], 6, 2)." ".substr($d[2], 8, 2).":".substr($d[2], 10, 2).":".substr($d[2], 12, 2);
	$row->{mail_title} = &plantext2html($d[3]);
	$row->{mail_body} = $d[4];
	$row->{mail_body} =~ s/__<<BR>>__/\n/gi;
	$row->{send_type} = &plantext2html($d[5]);
	$row->{mail_type} = &plantext2html($d[6]);
	$row->{backnumber} = $d[7];
	$row->{search_colname1} = $d[8];
	$row->{search_text1} = $d[9];
	$row->{search_colname2} = $d[10];
	$row->{search_text2} = $d[11];
	$row->{search_colname3} = $d[12];
	$row->{search_text3} = $d[13];
	$row->{search_colname4} = $d[14];
	$row->{search_text4} = $d[15];
	$row->{search_colname5} = $d[16];
	$row->{search_text5} = $d[17];
	
	if (!$row->{backnumber}) { next; }
	
	if ($row->{send_type} eq "1") {
		$row->{disp_send_type} = "分割";
	} else {
		$row->{disp_send_type} = "ノーマル";
	}
	if ($row->{mail_type} eq "plain") {
		$row->{mail_body} = &plantext2html($row->{mail_body});
	} elsif ($row->{mail_type} eq "html") {
		$row->{mail_body} = &plantext2html($row->{mail_body}, "onlybr");
	}
	# 送信先一覧
	my @send = split(/,/, $d[18]);
	my @senddata;
	foreach my $n (@send) {
		my $data;
		if (!$n) { next; }
		$data->{email} = $n;
		push(@senddata, $data);
	}
	$row->{total_count} = ($#senddata + 1);
	$row->{email_list} = \@senddata;
	push(@BACKDATA, $row);
}

@BACKDATA = sort { $b->{start_send_date} cmp $a->{start_send_date} } @BACKDATA;

my $data_ref;

# 送信先一覧
$data_ref->{backnumber_list} = \@BACKDATA;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
