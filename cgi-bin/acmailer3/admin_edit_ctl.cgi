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

$FORM{admin_email} = lc($FORM{admin_email});

#エラーチェック
&errorcheck($FORM{admin_name},1,"お名前を入力してください。");
if ($FORM{admin_name} =~ /[\"\'\@\;\:\,\.\<\>\\\[\]]/) {
	&error("差出人名の中に使用できない文字列が含まれています。");
}
&errorcheck($FORM{login_id},1,"IDを入力してください。");
if($FORM{login_id} && ($FORM{login_id} !~ /^[0-9a-zA-Z_\-]+$/ || length($FORM{login_id}) > 12)){
	&error("IDは半角英数字で12桁以内でご指定下さい。");
}
&errorcheck($FORM{login_pass},1,"パスワードを入力してください。");
&errorcheck($FORM{login_pass2},1,"パスワード（確認用）を入力してください。");
if($FORM{login_pass} && ($FORM{login_pass} !~ /^[0-9a-zA-Z_\-]+$/ || length($FORM{login_pass}) > 12)){
	&error("パスワードは半角英数字で12桁以内でご指定下さい。");
}
if($FORM{login_pass2} && ($FORM{login_pass2} !~ /^[0-9a-zA-Z_\-]+$/ || length($FORM{login_pass2}) > 12)){
	&error("パスワード（確認用）は半角英数字で12桁以内でご指定下さい。");
}

if($FORM{login_pass_org} ne $FORM{login_pass}){
	
	if($FORM{login_pass} ne $FORM{login_pass2}){
		&error("パスワードが一致しません。");
	}
}
&errorcheck($FORM{admin_email},1,"e-mailアドレスを入力してください。");
&errorcheck($FORM{admin_email},2,"e-mailアドレスを正しく入力してください。");
if($FORM{divnum} && ($FORM{divnum} !~ /^[0-9]+$/ || $FORM{divnum} < 10)){
	&error("分割送信件数を10以上の半角数値で設定してください。");
}
if($FORM{divwait} && ($FORM{divwait} !~ /^[0-9]+$/)){
	&error("分割待ち時間を半角数値で設定してください。");
}
if($FORM{send_type} == 1 && (!$FORM{divnum} || $FORM{divnum} < 10)){
	&error("送信モードが分割送信の場合、分割送信件数を10以上の半角数値で設定してください。");
}

if($FORM{send_type} == 1 && (!$FORM{divwait})){
	&error("送信モードが分割送信の場合、分割待ち時間を半角数値で設定してください。");
}
if ($FORM{homeurl} && $FORM{homeurl} !~ /^https{0,1}\:\/\/.*/) {
	&error("CGI設置URLはhttps://www.abc.com/acmailer/のような形式で入力してください。");
} elsif ($FORM{homeurl} !~ /^.*\/$/) {
	$FORM{homeurl} .= "/";
}
if ($FORM{mypath} && $FORM{mypath} !~ /\/$/) {
	$FORM{mypath} .= "/";
}

#ファイルオープン
open(IN, "+< ./data/admin.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @DATA;
my @LINES_ORG = <IN>;
foreach(@LINES_ORG){
	$_ =~ s/\r\n//g;
	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	if($_){
		push(@DATA,$_);
	}
}

my $regdata = "$FORM{admin_name}\t$FORM{login_id}\t$FORM{login_pass}\t$FORM{admin_email}\t$FORM{col1name}\t$FORM{col2name}\t$FORM{col3name}\t$FORM{col4name}\t$FORM{col5name}\t$FORM{col6name}\t$FORM{col7name}\t$FORM{col8name}\t$FORM{col9name}\t$FORM{col10name}\t$FORM{col1checked}\t$FORM{col2checked}\t$FORM{col3checked}\t$FORM{col4checked}\t$FORM{col5checked}\t$FORM{col6checked}\t$FORM{col7checked}\t$FORM{col8checked}\t$FORM{col9checked}\t$FORM{col10checked}\t$FORM{title}\t$FORM{sendmail_path}\t$FORM{send_type}\t$FORM{divnum}\t$FORM{backnumber_disp}\t$FORM{counter_disp}\t$FORM{homeurl}\t$FORM{merumaga_usermail}\t$FORM{merumaga_adminmail}\t$FORM{ssl}\t$FORM{divwait}\t$FORM{qmail}\t$FORM{rireki_email}\t$FORM{mypath}\t$FORM{double_opt}\n";
truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);

$S{login_id} = $FORM{login_id};
$S{login_pass} = $FORM{login_pass};
# セッション保存
&setsession($COOKIE{sid},%S);


my $row_admin = &get_admindata();
if ($row_admin->{ssl}) {
	$SYS->{homeurl_ssl} = $row_admin->{homeurl};
	$SYS->{homeurl_ssl} =~ s/^http\:\/\//https\:\/\//i;
} else {
	$SYS->{homeurl_ssl} =~ s/^https\:\/\//http\:\/\//i;
}


# autoreg.pl書き込み
if (-e "./lib/autoreg.pl") {
	my $regdata;
	open(IN, "+< ./lib/autoreg.pl") || &error("データファイルのオープンに失敗しました。");
	flock(IN, 2);
	my @LINES_ORG = <IN>;
	foreach(@LINES_ORG){
		$_ =~ s/\r\n//g;
		$_ =~ s/\r//g;
		$_ =~ s/\n//g;
		if($_ && $_ =~ /^my \$myfilepath \= \'.*\'\;/){
			$regdata .= 'my $myfilepath = '."'$FORM{mypath}';\n";
		} else {
			$regdata .= $_."\n";
		}
	}
	truncate(IN, 0);
	seek(IN, 0, 0);
	print(IN $regdata);
	close(IN);
}

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}admin_edit.cgi?okedit=1\n\n";
exit;
