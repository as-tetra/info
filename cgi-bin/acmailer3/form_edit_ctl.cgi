#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;
# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

#フォームデーター取得
my %FORM = &form("noexchange");

#エラーチェック
&errorcheck($FORM{form_mailtitle},1,"登録用　件名を入力してください。");
&errorcheck($FORM{form_mailbody},1,"登録用　本文を入力してください。");
&errorcheck($FORM{form2_mailtitle},1,"解除用　件名を入力してください。");
&errorcheck($FORM{form2_mailbody},1,"解除用　本文を入力してください。");

$FORM{form_mailtitle} =~ s/\t/ /gi;
$FORM{form_mailbody} =~ s/\t/ /gi;
$FORM{form2_mailtitle} =~ s/\t/ /gi;
$FORM{form2_mailbody} =~ s/\t/ /gi;

#ファイルオープン
open(IN, "+< ./data/form.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @LINES_ORG = <IN>;
my @DATA;
foreach(@LINES_ORG){
	$_ =~ s/\r\n//g;
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	if($_){
		push(@DATA,$_);
	}
}

$FORM{form_mailbody} =~ s/\n/__<<BR>>__/g;
$FORM{form2_mailbody} =~ s/\n/__<<BR>>__/g;

my $regdata = "$FORM{form_mailtitle}\t$FORM{form_mailbody}\t$FORM{form2_mailtitle}\t$FORM{form2_mailbody}\t$FORM{type}\n";

truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}form_edit.cgi?okedit=1\n\n";
exit;
