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
my $data_ref;
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
if(!$dispnum){ $dispnum = "50";$dispnum_d = 1; }
if($dispnum != "all"){
	$offset = ($page-1)*$dispnum;
}


my $row_admin = &get_admindata("nochange");

my @DATA = &openfile2array($SYS->{data_dir}."mailbuf.cgi");
my @data;
my $i = 0;
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{id} = $d[0];
	$row->{date} = $d[1];
	$row->{disp_date} = substr($d[1], 0, 4)."/".substr($d[1], 4, 2)."/".substr($d[1], 6, 2);
	$row->{email} = &plantext2html($d[2]);
	for(1..10) {
		$row->{"col".$_} = $d[($_ + 2)];
	}
	
	if(($dispnum eq "all") ||
	   ($offset <= $i && ($offset+$dispnum) > $i)){
		push (@data,$row);
	}
	$i++;
}

$data_ref->{loop} = \@data;

if($page > 1 ){
	$data_ref->{backlink} = 1;
}

if($dispnum ne "all" && ($offset+$dispnum) < ($i) ){
	$data_ref->{nextlink} = 1;
}

$data_ref->{page} = $page;
$data_ref->{page_m1} = $page-1;
$data_ref->{page_p1} = $page+1;
$data_ref->{dispnum} = $dispnum;

$data_ref->{totalnum} = $i;

my $pagenumall = 1;
if($dispnum >= 1 && $dispnum ne "all"){
	$pagenumall = ceil(($i) / $dispnum);
}
for(1..$pagenumall){
	if($_ == $page){
		$data_ref->{pagelink} .= "｜$_";
	}else{
		$data_ref->{pagelink} .= "｜<A href=\"clean_double_opt.cgi?page=$_&dispnum=$dispnum$data_ref->{search_url}\">$_</A>";
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

$data_ref->{oktext} = "$FORM{delnum}件削除されました。" if $FORM{okdel};

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
