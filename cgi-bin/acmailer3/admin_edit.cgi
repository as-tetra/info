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

my $row = &get_admindata("nochange");

if(!$row->{send_type}){
	# 通常送信
	$row->{send_type_0_checked} = "checked";
	$row->{send_type_1_checked} = "";
	$row->{send_type_2_checked} = "";
}elsif($row->{send_type} == 1){
	# 分割送信
	$row->{send_type_0_checked} = "";
	$row->{send_type_1_checked} = "checked";
	$row->{send_type_2_checked} = "";
}elsif($row->{send_type} == 2) {
	# バックグラウンド送信
	$row->{send_type_0_checked} = "";
	$row->{send_type_1_checked} = "";
	$row->{send_type_2_checked} = " checked ";
}

if(-x $row->{sendmail_path}){
	$row->{sendmail_path_check} = "サーバー上のパスと一致しました。";
}else{
	$row->{sendmail_path_check} = "サーバー上のパスと一致しません。";
}

if ($row->{backnumber_disp}) { $row->{backnumber_checked} = " checked "; }
if ($row->{counter_disp}) { $row->{counter_checked} = " checked "; }
if ($row->{merumaga_usermail}) { $row->{merumaga_usermail_checked} = " checked "; }
if ($row->{merumaga_adminmail}) { $row->{merumaga_adminmail_checked} = " checked "; }
if ($row->{ssl}) { $row->{ssl_checked} = " checked "; }
if ($row->{qmail}) { $row->{qmail_checked} = " checked "; }
if ($row->{rireki_email}) { $row->{rireki_email_checked} = " checked "; }
if ($row->{double_opt}) { $row->{double_opt_checked} = " checked "; }

# 空メールモジュールが組み込まれている場合
if (-e "./lib/autoreg.pl") {
	$row->{autoreg} = "1";
	if (!$row->{mypath}) {
		# pwdコマンドで取得
		my $path = `pwd`;
		$row->{mypath} = $path;
	} else {
		$row->{mypath_ok} = 1;
	}
}

my $data_ref = $row;

$data_ref->{oktext} = "変更されました。" if $FORM{okedit};

$data_ref->{writing_code} = $SYS->{writing_code};
$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
