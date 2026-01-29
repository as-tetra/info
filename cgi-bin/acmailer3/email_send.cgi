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
my $row_admin = &get_admindata("nochange");

if(!$row_admin->{admin_name}){
	&error("メール差出人名を設定してください。<a href=\"admin_edit.cgi\">→設定</a>");
}
if(!$row_admin->{admin_email}){
	&error("メール差出人メールアドレスを設定してください。<a href=\"admin_edit.cgi\">→設定</a>");
}
if(!CheckMailAddress($row_admin->{admin_email})){
	&error("メール差出人メールアドレスが正しくありません。<a href=\"admin_edit.cgi\">→設定</a>");
}

if(!-x $row_admin->{sendmail_path}){
	&error("sendmailのパスが正しくありません。こちらより<a href=\"admin_edit.cgi\">設定</a>してください。");
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
foreach(1..5){
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
		&error("メール配信を行うには、メールアドレス一覧の重複を取り除いてください。<a href=\"email_list.cgi\">（→確認）</a><br><br><a href=\"email_zyudel_ctl.cgi\" onclick=\"return confirm('重複メールアドレスを一括削除しますか？')\">今すぐ一括削除する</a>");
	}else{
		#エラーカウント
		if(!CheckMailAddress($d[0])){
			$errornum++;
			&error("メール配信を行うには、メールアドレスエラーを取り除いてください。<a href=\"email_list.cgi\">（→確認）</a><br><br><a href=\"email_errordel_ctl.cgi\" onclick=\"return confirm('エラーメールアドレスを一括削除しますか？（重複メールアドレス分のエラーメールも削除されます）')\">今すぐ一括削除する</a>");
		}else{
			$row->{status} = "◎ (正常)";
		}
	}
	$ZYU{$d[0]}++;
	

}

$data_ref->{totalnum} = $#DATA+1;

# メールテンプレート取得
@DATA = &openfile2array("$SYS->{data_dir}template.cgi");

my @TEMPLATEDATA;
my $java_array = " var arrtemplate = new Object(); \n";
foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	$row->{id} = $d[0];
	$row->{template_name} = &plantext2html($d[1]);
	$row->{mail_title} = &plantext2html($d[2]);
	$row->{mail_body} = $d[3];
	$row->{mail_body} =~ s/__<<BR>>__/\\n/gi;
	push(@TEMPLATEDATA, $row);
	$java_array .= "arrtemplate[\"$row->{id}1\"] = \"$row->{mail_title}\";\n";
	$java_array .= "arrtemplate[\"$row->{id}2\"] = \"$row->{mail_body}\";\n";
	# デフォルト表示
	if ($d[4]) {
		$data_ref->{mail_title} = &plantext2html($d[2]);
		$data_ref->{mail_body} = $d[3];
		$data_ref->{mail_body} =~ s/__<<BR>>__/\n/gi;
		$row->{template_name} .= "(デフォルト)";
		$row->{selected} = " selected ";
	}
}
# テンプレート一覧
$data_ref->{template_list} = \@TEMPLATEDATA;
$data_ref->{java_array} = $java_array;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
