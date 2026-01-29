#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;
my %FORM = &form();
# クッキーよりセッションデータ取得
if (!$FORM{sid}) { &error('<a href="m_login.cgi">ログイン画面</a>よりログインしなおしてください。'); }
my %COOKIE = &getcookie;
my %S = getsession($FORM{sid});

my $LOGIN = logincheck($S{login_id},$S{login_pass});
if ($FORM{mode} eq "hist") {

	if ($FORM{id} =~ /[^0-9]/ || !$FORM{id}) { &error("パラメータエラーです。"); }

	my @DATA = &openfile2array("$SYS->{data_dir}hist.cgi");
	my $data_ref;
	foreach my $ref (@DATA) {
		my @d = split(/\t/, $ref);
	
		if ($d[0] ne $FORM{id}) { next; }
	
		$data_ref->{id} = $d[0];
		$data_ref->{start_send_date} = substr($d[1], 0, 4)."/".substr($d[1], 4, 2)."/".substr($d[1], 6, 2)." ".substr($d[1], 8, 2).":".substr($d[1], 10, 2).":".substr($d[1], 12, 2);
		$data_ref->{end_send_date} = substr($d[2], 0, 4)."/".substr($d[2], 4, 2)."/".substr($d[2], 6, 2)." ".substr($d[2], 8, 2).":".substr($d[2], 10, 2).":".substr($d[2], 12, 2);
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
		} else {
			$data_ref->{disp_send_type} = "ノーマル";
		}
		if ($data_ref->{mail_type} eq "plain") {
			&error("テキストメールです。");
		} elsif ($data_ref->{mail_type} eq "html") {
			$data_ref->{disp_mail_type} = "HTMLメール";
		}
		
	}
	$data_ref->{mail_body} =~ s/__<<equal>>__/\=/gi;
	$data_ref->{mail_body} =~ s/__<<semicolon>>__/;/gi;
	$data_ref->{mail_body} =~ s/__<<BR>>__/<BR>/gi;
	print "Content-type: text/html; charset=EUC-JP\n\n";
	print '<html><head><title>プレビュー</title></head><body>';
	print $data_ref->{mail_body};
} else {
	$S{mail_body} =~ s/__<<equal>>__/\=/gi;
	$S{mail_body} =~ s/__<<semicolon>>__/;/gi;
	$S{mail_body} =~ s/__<<BR>>__/<BR>/gi;

	print "Content-type: text/html; charset=EUC-JP\n\n";
	print '<html><head><title>プレビュー</title></head><body>';

	print $S{mail_body};
}

if (!$SYS->{writing}) {
	print '
<div align="center"></div>
<div align="center">
<!-- ■■■■■■著作権について（重要！）■■■■■■ -->
<!-- 本システムは、AHREF(エーエイチレフ)に無断で下記著作権表示を削除・改変・非表示にすることは禁止しております -->
<!-- 著作権非表示に関しては、こちらをご確認下さい。 -->
<!-- http://www.ahref.org/cgityosaku.html -->
<!-- ■■■■■■■■■■■■■■■■■■■■■■■■ -->
<font size="-2" color=#999999>メルマガ配信CGI <a href="http://www.ahref.org/" title="メルマガ配信CGI ACMAILER" target="_blank">ACMAILER</a> Copyright (C) 2008 <a href="http://www.ahref.org/" target="_blank" title="エーエイチレフ">ahref.org</a> All Rights Reserved.
</font>
</div>
</div>';
}

print '</body></html>';
exit;
