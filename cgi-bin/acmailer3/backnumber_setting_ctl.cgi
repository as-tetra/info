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

if ($FORM{disp_num} eq "") { &error("公開件数を設定してください。"); }
if ($FORM{disp_num} =~ /[^0-9]/) { &error("公開件数は数値項目です。"); }

#ファイルオープン
open(IN, "+< ./data/backnumber_setting.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my $regdata = $FORM{disp_num}."\n";
truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);

print "Location: $SYS->{homeurl_ssl}backnumber_setting.cgi \n\n";
exit;
