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

# エラーチェック
if (!$FORM{template_name}) { &error("テンプレート名を入力してください。"); }
if (!$FORM{mail_title}) { &error("件名を入力してください。"); }
if (!$FORM{mail_body}) { &error("本文を入力してください。"); }

#ファイルオープン
open(IN, "+< ./data/template.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @DATA;
my @LINES_ORG = <IN>;
my $regdata;
foreach(@LINES_ORG){
	$_ =~ s/\r\n//g;
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	if($_){
		$regdata .= $_."\n";
	}
}

$FORM{template_name} =~ s/\t/ /gi;
$FORM{mail_title} =~ s/\t/ /gi;
$FORM{mail_body} =~ s/\t/ /gi;

$regdata .= time.$$."\t";	# ID
$regdata .= "$FORM{template_name}\t";	# 送信時間
$regdata .= "$FORM{mail_title}\t";	# 件名
$FORM{mail_body} =~ s/\r\n|\r|\n/__<<BR>>__/gi;
$regdata .= "$FORM{mail_body}\t";	# 本文
$regdata .= "\n";
truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);

print "Location: $SYS->{homeurl_ssl}mailtemplate_list.cgi \n\n";
exit;
