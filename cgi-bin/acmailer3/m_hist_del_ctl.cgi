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

if ($FORM{id} =~ /[^0-9]/ || !$FORM{id}) { &error("パラメータエラーです。"); }

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
	if ($d[0] ne $FORM{id} && $_) {
		$regdata .= $_."\n";
	}
}

truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);

print "Location: $SYS->{homeurl_ssl}m_hist_list.cgi?sid=$FORM{sid} \n\n";
exit;
