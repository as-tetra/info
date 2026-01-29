#!/usr/bin/perl

use lib "./lib/";
require './lib/setup.cgi';
use strict;

our $SYS;

my %COOKIE = &getcookie;
my $sid = decrypt_id($COOKIE{sid});
my $session_fn = $SYS->{dir_session}.".".$sid.".cgi";

my %FORM = &form;

# 入力データチェック
my $errordata;

$errordata .= "・メール差出人を入力してください。<br>" if !$FORM{admin_name};
$errordata .= "・メール差出人メールアドレスを入力してください。<br>" if !$FORM{admin_email};
if (!CheckMailAddress($FORM{admin_email})) {
	$errordata .= "・メール差出人メールアドレスを正しく入力してください。<br>";
}
$errordata .= "・ログインIDを入力してください。<br>" if !$FORM{login_id};
$errordata .= "・パスワードを入力してください。<br>" if !$FORM{login_pass};
if($FORM{login_id} && ($FORM{login_id} !~ /^[0-9a-zA-Z_\-]+$/ || length($FORM{login_id}) > 12)){
	$errordata .= "・IDは半角英数字で12桁以内でご指定下さい。<br>";
}
if($FORM{login_pass} && ($FORM{login_pass} !~ /^[0-9a-zA-Z_\-]+$/ || length($FORM{login_pass}) > 12)){
	$errordata .= "・パスワードは半角英数字で12桁以内でご指定下さい。<br>";
}

if ($FORM{homeurl} && $FORM{homeurl} !~ /^http\:\/\/.*/) {
	&error("CGI設置URLはhttps://www.abc.com/acmailer/のような形式で入力してください。");
} elsif ($FORM{homeurl} !~ /^.*\/$/) {
	$FORM{homeurl} .= "/";
}



&error("$errordata") if $errordata;

# データ設定****************************************************************************
my $row_admin = &get_admindata("nochange");
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

my $regdata = "$FORM{admin_name}\t$FORM{login_id}\t$FORM{login_pass}\t$FORM{admin_email}\t$row_admin->{col1name}\t$row_admin->{col2name}\t$row_admin->{col3name}\t$row_admin->{col4name}\t$row_admin->{col5name}\t$row_admin->{col6name}\t$row_admin->{col7name}\t$row_admin->{col8name}\t$row_admin->{col9name}\t$row_admin->{col10name}\t$row_admin->{col1checked}\t$row_admin->{col2checked}\t$row_admin->{col3checked}\t$row_admin->{col4checked}\t$row_admin->{col5checked}\t$row_admin->{col6checked}\t$row_admin->{col7checked}\t$row_admin->{col8checked}\t$row_admin->{col9checked}\t$row_admin->{col10checked}\tメルマガ配信CGI ACMAILER3.20\t$FORM{sendmail_path}\t0\t$row_admin->{divnum}\t1\t1\t$FORM{homeurl}\t1\t1\t0\n";
truncate(IN, 0);
seek(IN, 0, 0);
print(IN $regdata);
close(IN);
#**************************************************************************************
open(IN, "+< ./data/mail.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
truncate(IN, 0);
seek(IN, 0, 0);
print(IN $FORM{admin_email});
close(IN);

# デフォルトで管理者のメールアドレスを挿入

# 古いセッションデーター削除
my @temp_files;
opendir(DIR, $SYS->{dir_session});
@temp_files = (grep !/^\.\.?$/,readdir DIR);
closedir(DIR);
foreach(@temp_files){
	if((time - 86400) > ((stat("$SYS->{dir_session}$_"))[9])){
		unlink "$SYS->{dir_session}$_";
	}
}
# フォームデーター整形
my %S;
$S{login_id} = $FORM{login_id};
$S{login_pass} = $FORM{login_pass};

my %TIME = &getdatetime;
# ファイルを使わず、pidでの場合
$sid = "$TIME{sec}".$$;

my $sid_e = encrypt_id($sid);
my $sid_ec = $sid_e;
$sid_ec =~ s/(\W)/sprintf("%%%02X", unpack("C", $1))/eg;

# セッション保存
&setsession($sid_e,%S);

$FORM{login_id} =~ s/%([a-f\d]{2})/pack 'H2',$1/egi;

# クッキー書き込み
if($FORM{memory}){
	my ($secg, $ming, $hourg, $mdayg, $mong, $yearg, $wdayg) = gmtime(time + (86400*30));
	my @mons = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
	my @week = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
	my $cookieexpires = sprintf("%s\, %02d-%s-%04d %02d:%02d:%02d GMT", $week[$wdayg], $mdayg, $mons[$mong], $yearg+1900, $hourg, $ming, $secg);
	
	print "Set-Cookie: sid=$sid_ec; path=/; \n";

}else{
	
	my ($secg, $ming, $hourg, $mdayg, $mong, $yearg, $wdayg) = gmtime(time + (86400*3));
	my @mons = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
	my @week = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
	my $cookieexpires = sprintf("%s\, %02d-%s-%04d %02d:%02d:%02d GMT", $week[$wdayg], $mdayg, $mons[$mong], $yearg+1900, $hourg, $ming, $secg);
	print "Set-Cookie: sid=$sid_ec; path=/; \n";
}

print "Location: $SYS->{homeurl_ssl}index.cgi\n\n";
exit;
