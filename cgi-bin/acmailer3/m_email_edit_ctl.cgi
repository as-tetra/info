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

my $data_ref;

#エラーチェック
if(!$FORM{email}){
	&error("メールアドレスを入力してください。");
}
#エラーチェック
if(!CheckMailAddress($FORM{email})){
	&error("メールアドレスを正しく入力してください。");
}

$FORM{email} = lc $FORM{email};

my $row = &get_admindata();

my $colsdata;
foreach(1..10){
	my $col = "col".$_;
	if($row->{$col."checked"} && ($FORM{$col} eq "")){
		&error("「".$row->{$col."name"}."」は必須項目です");
	}
	#$FORM{$col} =~ s/\t//g;
	#$FORM{$col} =~ s/"//g;
	#$FORM{$col} =~ s/'//g;
	$FORM{$col} =~ s/,/，/g;
	$colsdata .= ",$FORM{$col}";
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
	
	if($FORM{email} ne $FORM{email_org}){
		if($mail[0] && $mail[0] eq $FORM{email}){
			&error("「$FORM{email}」はすでに登録されています。");
		}
	}
	if($mail[0] && $mail[0] eq $FORM{email_org}){
		$regdata .= "$FORM{email}" . "$colsdata\n";
	}else{
		$regdata .= $_."\n";
	}
}

seek(IN, 0, 0);
print(IN $regdata);
truncate(IN,tell(IN));
close(IN);

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}m_email_list.cgi?okedit=1&sid=$FORM{sid}\n\n";
