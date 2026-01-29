#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";

# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});



my %FORM = &form;



my $regdata;
#ファイルオープン
open(IN, "+< $SYS->{data_dir}mail.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
seek(IN, 0, 0);
print(IN "");
truncate(IN,tell(IN));
close(IN);

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}email_list.cgi?okalldel=1\n\n";
