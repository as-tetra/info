#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;
our $SYS;

my %FORM = &form("noexchange");
# クッキーよりセッションデータ取得
if (!$FORM{sid}) { &error('<a href="m_login.cgi">ログイン画面</a>よりログインしなおしてください。'); }
my %COOKIE = &getcookie;
my %S = getsession($FORM{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

my @DATA = &openfile2array("$SYS->{data_dir}hist.cgi");

if ($FORM{id} =~ /[^0-9]/ || !$FORM{id}) { &error("パラメータエラーです。"); }

my $data_ref;
foreach my $ref (@DATA) {
	my @d = split(/\t/, $ref);
	
	if ($d[0] ne $FORM{id}) { next; }
	
	$data_ref->{id} = $d[0];
	$data_ref->{start_send_date} = substr($d[1], 0, 4)."/".substr($d[1], 4, 2)."/".substr($d[1], 6, 2)." ".substr($d[1], 8, 2).":".substr($d[1], 10, 2).":".substr($d[1], 12, 2);

	if ($d[2]) {
		$data_ref->{end_send_date} = substr($d[2], 0, 4)."/".substr($d[2], 4, 2)."/".substr($d[2], 6, 2)." ".substr($d[2], 8, 2).":".substr($d[2], 10, 2).":".substr($d[2], 12, 2);
		$data_ref->{bgcolor} = "#FFFFFF";
	} else {
		$data_ref->{end_send_date} = '&nbsp;';
		$data_ref->{bgcolor} = "#FFCCCC";
	}
	if ($d[20] == 1 || !$d[20]) {
		$data_ref->{fail} = "1";
	}
	$data_ref->{mail_title} = &plantext2html($d[3]);
	$data_ref->{mail_body} = $d[4];
	$data_ref->{mail_body} =~ s/__<<BR>>__/\n/gi;
	$data_ref->{send_type} = &plantext2html($d[5]);
	$data_ref->{mail_type} = &plantext2html($d[6]);
	$data_ref->{backnumber} = $d[7];
	$data_ref->{search_colname1} = $d[8];
	$data_ref->{search_text1} = $d[9];
	$data_ref->{search_colname2} = $d[10];
	$data_ref->{search_text2} = $d[11];
	$data_ref->{search_colname3} = $d[12];
	$data_ref->{search_text3} = $d[13];
	$data_ref->{search_colname4} = $d[14];
	$data_ref->{search_text4} = $d[15];
	$data_ref->{search_colname5} = $d[16];
	$data_ref->{search_text5} = $d[17];
	if ($data_ref->{backnumber}) { $data_ref->{backnumber_selected} = " selected "; }
	if ($data_ref->{send_type} eq "1") {
		$data_ref->{disp_send_type} = "分割";
	} elsif ($data_ref->{send_type} eq "2") {
		$data_ref->{disp_send_type} = "バックグラウンド処理";
	} elsif ($data_ref->{send_type} eq "0") {
		$data_ref->{disp_send_type} = "ノーマル";
	}
	if ($data_ref->{mail_type} eq "plain") {
		$data_ref->{disp_mail_type} = "テキストメール";
		$data_ref->{mail_body} = &plantext2html($data_ref->{mail_body});
	} elsif ($data_ref->{mail_type} eq "html") {
		# タグ抜き取り
		$data_ref->{mail_body} =~ s/<.*?>//gi;
		$data_ref->{mail_body} = &plantext2html($data_ref->{mail_body});
		$data_ref->{disp_mail_type} = "HTMLメール";
		$data_ref->{htmlpreview} = "1";
	}
	# 送信先一覧
	my @send = split(/,/, $d[18]);
	my @senddata;
	foreach my $n (@send) {
		my $data;
		$n =~ s/ //gi;
		if (!$n) { next; }
		$data->{email} = $n;
		push(@senddata, $data);
	}
	$data_ref->{total_count} = $d[19];
	$data_ref->{email_list} = \@senddata;
}

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
$data_ref->{sid} = $FORM{sid};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
