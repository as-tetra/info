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

# =============================
# 絞込みリスト
# =============================
my $row_admin = &get_admindata("nochange");
my (@search, $search_exist);

my $COL;
foreach(1..5){
	my $row;
	$row->{search_id} = $_;
	
	
	my @cols;
	foreach(1..10) {
		my $row2;
		my $d = "col".$_."name";
		if (!$row_admin->{$d}) { next; }
		$row2->{col} = $_;
		$row2->{colname} = $row_admin->{$d};
	
		$row2->{"search_col"} = $row_admin->{"col".$FORM{"search".$row->{search_id}}."name"};
		$row2->{"search_text"} = $FORM{"search_text".$row->{search_id}};
		$row2->{num} = $_;
		if ($row2->{"search_col"} ne "" && $row2->{"search_text"} ne "") { $search_exist = 1; }

		if ($row2->{col} eq $FORM{"search".$row->{search_id}}) { $row2->{selected} = " selected "; }
		push(@{$COL->{'col'.$row->{search_id}}}, $row2);
	}
	
	$row->{select} = \@{$COL->{'col'.$row->{search_id}}};
	$row->{search_text} = $FORM{"search_text".$_};
	$data_ref->{"search_text".$_} = $FORM{"search_text".$_};
	$data_ref->{"search".$_} = $FORM{"search".$_};
	push(@search,$row);
	my $sjis_searchtext = $FORM{"search_text".$_};
	&jcode::convert(\$sjis_searchtext,'sjis','euc');
	$data_ref->{search_url} .= "&search".$_."=".$FORM{"search".$_}."&search_text".$_."=".&urlencode($sjis_searchtext);
}
$data_ref->{search} = \@search;
#$data_ref->{col_list} = \@cols;


my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");
my @data;
my (%ZYU, $zyunum, $errornum, $i);
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = &plantext2html($d[0]);
	for (1..10) {
		$row->{"col".$_} = &plantext2html($d[$_]);
	}
	$row->{email_disp} = urlencode($d[0]);
	my $email_url = $row->{email};
	&jcode::convert(\$email_url, "sjis", "euc");
	$row->{email_url} = &urlencode($email_url);
	
	$row->{i} = $i+1;
	
	# 絞り込み適用
	my $no;
	if ($search_exist) {
		for (my $i = 1; $i <= 5; $i++) {
			my $column = $row_admin->{"col".$FORM{"search".$i}."name"};
			my $word = $FORM{"search_text".$i};
			if ($word eq "") { next; }
			for(1..10) {
				if ($row_admin->{"col".$_."name"} eq $column && ($d[$_] ne $word)) {
					$no = 1;
				}
			}
		}
	}
	if ($search_exist && ($no)) { next; }
	
	
	#重複カウント
	if($ZYU{$d[0]}){
		$zyunum++;
		$row->{status} = "<font color=\"red\">× (重複)</font>";
	}else{
		#エラーカウント
		if(!CheckMailAddress($d[0])){
			$errornum++;
			$row->{status} = "<font color=\"red\">× (エラー)</font>";
		}else{
			$row->{status} = "◎ (正常)";
		}
	}
	$ZYU{$d[0]}++;
	
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
$data_ref->{zyunum} = $zyunum || 0;
$data_ref->{errornum} = $errornum || 0;
$data_ref->{emailnum} = $data_ref->{totalnum} - $data_ref->{zyunum} - $data_ref->{errornum};

my $pagenumall = 1;
if($dispnum >= 1 && $dispnum ne "all"){
	$pagenumall = ceil(($i) / $dispnum);
}
for(1..$pagenumall){
	if($_ == $page){
		$data_ref->{pagelink} .= "｜$_";
	}else{
		$data_ref->{pagelink} .= "｜<A href=\"email_list.cgi?page=$_&dispnum=$dispnum$data_ref->{search_url}\">$_</A>";
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

$data_ref->{oktext} = "新規登録されました。" if $FORM{okadd};
$data_ref->{oktext} = "変更されました。" if $FORM{okedit};
$data_ref->{oktext} = "削除されました。" if $FORM{okdel};
$data_ref->{oktext} = "重複メールが一括削除されました。" if $FORM{okzyudel};
$data_ref->{oktext} = "エラーメールが一括削除されました。" if $FORM{okerrordel};
$data_ref->{oktext} = "メールアドレスが完全削除されました。" if $FORM{okalldel};

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
