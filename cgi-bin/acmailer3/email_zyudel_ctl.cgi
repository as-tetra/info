#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;
# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});
my %FORM = &form;
my $data_ref;

my $regdata;
#ファイルオープン
open(IN, "+< $SYS->{data_dir}mail.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @MAIL = <IN>;
my %ZYU;
foreach(@MAIL){
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	my @d =split(/,/,$_);

	#重複カウント
	if($ZYU{$d[0]}){
		#削除処理
	}else{
		$regdata .= $_."\n";
	}
	$ZYU{$d[0]}++;
}
seek(IN, 0, 0);
print(IN $regdata);
truncate(IN,tell(IN));
close(IN);

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}email_list.cgi?okzyudel=1\n\n";
exit;
