#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;

my %FORM = &form();

&limit_access('backnumber.cgi,m_backnumber.cgi');

# 管理情報取得
my $row_admin = &get_admindata();

if (!$row_admin->{backnumber_disp}) {
	&error("表示できません。");
}

if (!$FORM{id}) {
	&error("パラメータエラーです。");
}

print "Content-type: text/html; charset=EUC-JP\n\n";
print '<html><head><title>プレビュー</title></head><body>';

my %FORM = &form("noexchange");
my @DATA = &openfile2array("$SYS->{data_dir}hist.cgi");

my @SETTING = &openfile2array("$SYS->{data_dir}backnumber_setting.cgi");
my $max = $SETTING[0];

my $data_ref;
my @BACKDATA;

# ソート
@DATA = sort { (split(/\t/,$b))[1] cmp (split(/\t/,$a))[1] } @DATA;

my $count = 0;
foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	my $i = 0;
	foreach my $n (qw(id start_send_date end_send_date mail_title mail_body send_type mail_type backnumber search_colname1 search_text1 search_colname2 search_text2 search_colname3 search_text3 search_colname4 search_text4 search_colname5 search_text5 send)) {
		$row->{$n} = $d[$i];
		$i++;
	}
	
	if (!$row->{backnumber}) { next; }
	
	# 詳細データ
	if ($FORM{id} eq $row->{id}) {
		if ($row->{mail_type} eq "plain") {
			print "テキストメールです。";
			exit;
		} else {
			$row->{mail_body} =~ s/__<<equal>>__/\=/gi;
			$row->{mail_body} =~ s/__<<semicolon>>__/;/gi;
			$row->{mail_body} =~ s/__<<BR>>__/<BR>/gi;
			print $row->{mail_body};
		}
	}
	$count++;
	if ($count >= $max) { last; }
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
