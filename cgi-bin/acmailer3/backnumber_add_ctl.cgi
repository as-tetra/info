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

#ファイルオープン
open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @DATA;
my @LINES_ORG = <IN>;
my $regdata;
foreach(@LINES_ORG){
	$_ =~ s/\r\n//g;
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	my @d = split(/\t/, $_);
	my $row;
	$row->{id} = $d[0];
	$row->{start_send_date} = $d[1];
	$row->{end_send_date} = $d[2];
	$row->{mail_title} = $d[3];
	$row->{mail_body} = $d[4];
	$row->{send_type} = $d[5];
	$row->{mail_type} = $d[6];
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
	if ($row->{backnumber}) { $row->{backnumber_selected} = " selected "; }
	if ($row->{send_type} eq "1") {
		$row->{disp_send_type} = "分割";
	} else {
		$row->{disp_send_type} = "ノーマル";
	}
	$row->{senderlist} = $d[18];
	
	if ($FORM{$row->{id}."_backnumber"}) {
		$row->{backnumber} = "1";
	} else {
		$row->{backnumber} = "";
	}
	$row->{send_num} = $d[19];
	$row->{status} = $d[20];
	$regdata .= "$row->{id}\t$row->{start_send_date}\t$row->{end_send_date}\t$row->{mail_title}\t$row->{mail_body}\t$row->{send_type}\t$row->{mail_type}\t$row->{backnumber}\t$row->{search_colname1}\t$row->{search_text1}\t$row->{search_colname2}\t$row->{search_text2}\t$row->{search_colname3}\t$row->{search_text3}\t$row->{search_colname4}\t$row->{search_text4}\t$row->{search_colname5}\t$row->{search_text5}\t$row->{senderlist}\t$row->{send_num}\t$row->{status}\n";
}

truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);

print "Location: $SYS->{homeurl_ssl}hist_list.cgi \n\n";
exit;
