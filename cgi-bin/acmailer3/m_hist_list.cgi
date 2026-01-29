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

# *** ページ設定 *** #
my $page = $FORM{page};
my $dispnum = $FORM{dispnum};
my ($offset, $dispnum_d);
if($page and ( $page < 1 or $page >= 2000000000)){
	&error("PAGEの指定が正しくありません。");
}
if($dispnum and $dispnum != "all" and ( $dispnum < 1 or $dispnum >= 2000000000)){
	&error("表示件数の指定が正しくありません。");
}

if(!$page){ $page = 1; }
if(!$dispnum){ $dispnum = "10";$dispnum_d = 1; }
if($dispnum != "all"){
	$offset = ($page-1)*$dispnum;
}
# ****************** #

my @HISTDATA;
my $i = 0;


@DATA = sort { (split(/\t/, $b))[1] cmp (split(/\t/, $a))[1] } @DATA;

foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	# 絞込み
	my $sdate;
	if ($FORM{s_year} && $FORM{s_mon} && $FORM{s_day}) { $sdate = sprintf("%04d", $FORM{s_year}).sprintf("%02d", $FORM{s_mon}).sprintf("%02d", $FORM{s_day}); }
	my $edate;
	if ($FORM{e_year} && $FORM{e_mon} && $FORM{e_day}) { $edate = sprintf("%04d", $FORM{e_year}).sprintf("%02d", $FORM{e_mon}).sprintf("%02d", $FORM{e_day}); }
	my $stdate = substr($d[1], 0, 8);

	if ($sdate && $edate && ($stdate < $sdate || $stdate > $edate)) {
		next;
	} elsif ($sdate && !$edate && $stdate < $sdate) {
		next;
	} elsif ($edate && !$sdate && $stdate > $edate) {
		next;
	}
	
	$row->{id} = $d[0];
	# 携帯版は秒はなし
	$row->{start_send_date} = substr($d[1], 0, 4)."/".substr($d[1], 4, 2)."/".substr($d[1], 6, 2)." ".substr($d[1], 8, 2).":".substr($d[1], 10, 2);
	if ($d[2]) {
		$row->{end_send_date} = substr($d[2], 0, 4)."/".substr($d[2], 4, 2)."/".substr($d[2], 6, 2)." ".substr($d[2], 8, 2).":".substr($d[2], 10, 2);
	} else {
		$row->{end_send_date} = '&nbsp;';
	}
	if ($d[20] == 1 || !$d[20]) {
		$row->{fail} = "1";
	}
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
	if ($row->{backnumber}) { $row->{backnumber_selected} = " checked "; }
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
	#my @send = split(/,/, $d[18]);
	#my @senddata;
	#foreach my $n (@send) {
	#	my $data;
	#	$n =~ s/ //gi;
	#	if (!$n) { next; }
	#	$data->{email} = $n;
	#	push(@senddata, $data);
	#}
	$row->{total_count} = ($d[19]);
	#$row->{email_list} = \@senddata;

	$row->{sid} = $FORM{sid};
	if(($dispnum eq "all") ||
	   ($offset <= $i && ($offset+$dispnum) > $i)){
		push (@HISTDATA,$row);
	}
	$i++;
}


my $data_ref;
# *** ページ設定 *** #
if($page > 1 ){
	$data_ref->{backlink} = 1;
}

if($dispnum ne "all" && ($offset+$dispnum) < ($#DATA+1) ){
	$data_ref->{nextlink} = 1;
}

$data_ref->{page} = $page;
$data_ref->{page_m1} = $page-1;
$data_ref->{page_p1} = $page+1;
$data_ref->{dispnum} = $dispnum;

$data_ref->{totalnum} = $#DATA+1;

foreach my $n (qw(s_year s_mon s_day e_year e_mon e_day)) {
	$data_ref->{$n} = $FORM{$n};
	$data_ref->{search_url} .= "&$n=".$FORM{$n};
}

my $pagenumall = 1;
if($dispnum >= 1 && $dispnum ne "all"){
	$pagenumall = ceil(($#DATA+1) / $dispnum);
}
for(1..$pagenumall){
	if($_ == $page){
		$data_ref->{pagelink} .= "｜$_";
	}else{
		$data_ref->{pagelink} .= "｜<A href=\"m_hist_list.cgi?page=$_&dispnum=$dispnum$data_ref->{search_url}&sid=$FORM{sid}\">$_</A>";
	}
}

#表示件数切り替え
if($FORM{dispnum}){
	$data_ref->{dispnum10_selected} = " selected" if ($dispnum eq "10");
	$data_ref->{dispnum25_selected} = " selected" if ($dispnum eq "25");
	$data_ref->{dispnum50_selected} = " selected" if ($dispnum eq "50");
	$data_ref->{dispnum100_selected} = " selected" if ($dispnum eq "100");
	$data_ref->{dispnumall_selected} = " selected" if ($dispnum eq "all");
}
# ****************** #

# 送信先一覧
$data_ref->{hist_list} = \@HISTDATA;

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
