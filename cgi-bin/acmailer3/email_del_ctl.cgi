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
my $data_ref = &get_admindata();
my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");
my @data;
my %ZYU;
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = &plantext2html(lc($d[0]));
	$ZYU{$d[0]}++;
}

my %DELMAIL;

$FORM{emailall} =~ s/\r//;
my @mailline = split(/\n/,$FORM{emailall});
my $i;
foreach(@mailline){

	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	if($_){
		my @mail = split(/,/,$_);
		my $row;

		$row->{i} = ++$i;
		$row->{email} = &plantext2html(lc($mail[0]));
		for(1..10) {
			$row->{"col".$_} = &plantext2html($mail[$_]);
		}
	
		if(!CheckMailAddress($mail[0])){
			$row->{status} .= "<font color=\"red\">× (メールアドレスエラー)</font><br>";
		}elsif(!$ZYU{lc($mail[0])}){
			$row->{status} .= "<font color=\"red\">× (登録無し)</font><br>";
		}
	
		if(!$row->{status}){
			$DELMAIL{$mail[0]}++;
		}else{
			&error("処理を中断しました。<br>操作中にデータファイルの更新があった可能性があります。<br>$row->{email}<br>$row->{status}");
		}
	}
}

my $regdata;
#ファイルオープン
open(IN, "+< $SYS->{data_dir}mail.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @MAIL = <IN>;
foreach(@MAIL){

	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	my @mail =split(/,/,$_);
	if(lc($mail[0]) && lc($DELMAIL{$mail[0]})){
		#削除処理
	}else{
		$regdata .= $_."\n";
	}
}
seek(IN, 0, 0);
print(IN $regdata);
truncate(IN,tell(IN));
close(IN);

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}email_list.cgi?okdel=1\n\n";
