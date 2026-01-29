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

my $row_admin = &get_admindata("nochange");

if(!$row_admin->{admin_name}){
	&error("メール差出人名を設定してください。");
}
if(!$row_admin->{admin_email}){
	&error("メール差出人メールアドレスを設定してください。");
}
if(!CheckMailAddress($row_admin->{admin_email})){
	&error("メール差出人メールアドレスが正しくありません。");
}

if(!-x $row_admin->{sendmail_path}){
	&error("sendmailのパスが正しくありません。");
}

my $data_ref = $row_admin;

my (@cols, @search);
foreach(1..10){
	my $row;
	my $d = "col".$_."name";
	if (!$row_admin->{$d}) { next; }
	$row->{col} = $_;
	$row->{colname} = $row_admin->{$d};
	push(@cols,$row);
}
foreach(1..2){
	my $row;
	$row->{search_id} = $_;
	$row->{select} = \@cols;
	push(@search,$row);
	
}
$data_ref->{search} = \@search;
$data_ref->{col_list} = \@cols;

my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");
my (%ZYU, $zyunum, $errornum, $i);
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = &plantext2html($d[0]);
	$row->{email_disp} = urlencode($d[0]);
	
	$row->{i} = $i+1;
	
	#重複カウント
	if($ZYU{$d[0]}){
		$zyunum++;
		&error("メール配信を行うには、メールアドレス一覧の重複を取り除いてください。<a href=\"m_email_list.cgi?sid=$FORM{sid}\">（→確認）</a>");
	}else{
		#エラーカウント
		if(!CheckMailAddress($d[0])){
			$errornum++;
			&error("メール配信を行うには、メールアドレスエラーを取り除いてください。<a href=\"m_email_list.cgi?sid=$FORM{sid}\">（→確認）</a>");
		}else{
			$row->{status} = "◎ (正常)";
		}
	}
	$ZYU{$d[0]}++;
	

}

$data_ref->{totalnum} = $#DATA+1;

# メールテンプレート取得
@DATA = &openfile2array("$SYS->{data_dir}template.cgi");

foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	if ($d[4]) {
		$data_ref->{mail_title} = &plantext2html($d[2]);
		$data_ref->{mail_body} = $d[3];
		$data_ref->{mail_body} =~ s/__<<BR>>__/\n/gi;
	}
}

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
$data_ref->{sid} = $FORM{sid};


# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
