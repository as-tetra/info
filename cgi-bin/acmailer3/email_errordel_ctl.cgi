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

my $regdata;
#ファイルオープン
open(IN, "+< $SYS->{data_dir}mail.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @MAIL = <IN>;
foreach(@MAIL){
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	my @d =split(/,/,$_);
	#エラーカウント
	if(!CheckMailAddress($d[0])){
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
print "Location: $SYS->{homeurl_ssl}email_list.cgi?okerrordel=1\n\n";
exit;
