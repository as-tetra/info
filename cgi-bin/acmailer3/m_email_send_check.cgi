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

# セッション初期化
foreach my $n (qw(mail_title mail_body sender_mail)) {
	$S{$n} = "";
}

my $LOGIN = logincheck($S{login_id},$S{login_pass});

my $data_ref;
my $row_admin = &get_admindata();
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
if (!$FORM{mail_title}) { &error("件名を入力してください。"); }
if (!$FORM{mail_body}) { &error("本文を入力してください。"); }
$data_ref = $row_admin;

# 絞込み
my @search;
my $search_exist;
for (1..5) {
	my $row;
	$row->{"search_col"} = $row_admin->{"col".$FORM{"search".$_}."name"};
	$row->{"search_text"} = $FORM{"search_text".$_};
	$row->{num} = $_;
	if ($row->{"search_col"} ne "" && $row->{"search_text"} ne "") { $search_exist = 1; }
	push(@search, $row);
}
$data_ref->{search} = \@search;

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

#件名
$data_ref->{mail_title} = &plantext2html($FORM{mail_title},"nobr");
$data_ref->{mail_title_html} = &plantext2html($FORM{mail_title});
$S{mail_title} = $FORM{mail_title};

#本文
$data_ref->{mail_body} = &plantext2html($FORM{mail_body},"nobr");
$data_ref->{mail_body_html} = &plantext2html($FORM{mail_body});

$data_ref->{mail_body_html} =~ s/\r\n|\r|\n/<br>/gi;
$S{mail_body} = $FORM{mail_body};

$data_ref->{mail_type} = $FORM{mail_type};
if ($FORM{mail_type} eq "plain") {
	$data_ref->{disp_mail_type} = "テキスト";
} else {
	$data_ref->{disp_mail_type} = "HTML";
	$data_ref->{htmlpreview} = "1";
}

$data_ref->{mail_title_html} =~ s/\{EMAIL\}/<font color=\"blue\"><b>\{EMAIL\}<\/b><\/font>/g;
$data_ref->{mail_body_html} =~ s/\{EMAIL\}/<font color=\"blue\"><b>\{EMAIL\}<\/b><\/font>/g;
for(1..10) {
	my $n = "COL$_";
	$data_ref->{mail_title_html} =~ s/\{$n\}/<font color=\"blue\"><b>\{$n\}<\/b><\/font>/g;
	$data_ref->{mail_body_html} =~ s/\{$n\}/<font color=\"blue\"><b>\{$n\}<\/b><\/font>/g;
}
$data_ref->{mail_title_html} =~ s/\t/ /gi;
$data_ref->{mail_body_html} =~ s/\t/ /gi;

#配信テスト
if($FORM{send_test}){
	$data_ref->{send_test_disp} = "配信テスト";
}else{
	$data_ref->{send_test_disp} = "<font color=\"red\"><b>本番送信</b></font>";
}
$data_ref->{send_test} = &plantext2html($FORM{send_test});

# 送信先一覧
my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");
my @predata;
my (%ZYU, $zyunum, $errornum, $i);
$S{sender_data} = "";
my $sendertotal = 0;
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = &plantext2html($d[0]);
	for (1..10) {
		$row->{"col".$_} = &plantext2html($d[$_]);
	}
	$row->{email_disp} = urlencode($d[0]);
	$row->{i} = $i+1;
	
	# 絞り込み適用
	my $no;
	if ($search_exist) {
		for (my $i = 1; $i <= 5; $i++) {
			my $column = $row_admin->{"col".$FORM{"search".$i}."name"};
			my $word = $FORM{"search_text".$i};
			if ($word eq "") { next; }
			for(1..10) {
				if ($row_admin->{"col".$_."name"} eq $column && ($d[$_] ne $word)) {
					$no = 1;
				}
			}
		}
	}
	if ($search_exist && ($no)) { next; }
	
	# プレビューは10件だけ
	if (($i + 1) <= 10) {
		$row->{subject} = $FORM{mail_title};
		$row->{body} = $FORM{mail_body};
		$row->{subject} =~ s/{EMAIL}/$row->{email}/gi;
		$row->{body} =~ s/{EMAIL}/$row->{email}/gi;
		# 置換作業
		for(1..10) {
			my $n = "col$_";
			$row->{subject} =~ s/{COL$_}/$row->{$n}/gi;
			$row->{body} =~ s/{COL$_}/$row->{$n}/gi;
		}
		$row->{subject} =~ s/\t/ /gi;
		$row->{body} =~ s/\t/ /gi;
	
		# プレビューはテキストに変更
		$row->{body} = &plantext2html($row->{body}, "nobr");
		$row->{subject} =~ s/\r\n|\r|\n/<br>/gi;
		$row->{body} =~ s/\r\n|\r|\n/<br>/gi;
		$row->{body} =~ s/'/’/gi;
	
		$row->{num} = ($i + 1);
		# プレビュー用本文は1000文字以内
		&jcode::convert(\$row->{body}, "sjis","euc");
		$row->{body} = z_substr($row->{body}, 0, 1000);
		&jcode::convert(\$row->{body}, "euc","sjis");
		push(@predata, $row);
	}
	
	$ZYU{$d[0]}++;
	$i++;
	$sendertotal++;
	
	# セッション用データ作成***************************
	$S{sender_data} .= $_."\n";
	#**************************************************
	
}
$data_ref->{pre_list} = \@predata;

if ($sendertotal == 0) { &error("送り先がありません。"); }
$data_ref->{sender_total} = $sendertotal;

$S{mail_title} =~ s/;/__<<semicolon>>__/gi;
$S{mail_body} =~ s/;/__<<semicolon>>__/gi;
$S{mail_title} =~ s/=/__<<equal>>__/gi;
$S{mail_body} =~ s/=/__<<equal>>__/gi;
$S{mail_title} =~ s/\t//gi;
$S{mail_body} =~ s/\t//gi;

# セッション保存用絞込みテキスト
for(1..5) {
	$S{"search_colname".$_} = $row_admin->{"col".$FORM{"search".$_}."name"};
	$S{"search_text".$_} = $FORM{"search_text".$_};
}

#******************#
# セッションに保存 #
#******************#
&setsession($FORM{sid}, %S);

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
$data_ref->{sid} = $FORM{sid};
my $pid;
# FORKできるか試す
eval{
	# 処理をバックグラウンドでする
	FORK: {
		if ($pid = fork) {
			# バックグラウンド送信に設定
			$data_ref->{send_type} = 2;
			
			# HTMLテンプレートオープン
			my $template = &newtemplate();
			# パラメーターを埋める
			$template->param($data_ref);
			# HTML表示
			&printhtml($template,"sjis");
			exit;
			
			# STDOUTを閉じないと、apacheが終了statusを返さないらしい。よって、ブラウザが開放されない。
			close(STDOUT);
			# 子プロセスの終了を待っていないと、子がZombieになってまうらしい
			wait;
		} elsif (defined $pid) {
			# バックグラウンド処理
			
			
		} elsif ($! =~ /No more process/) {
			# プロセスが多すぎる場合、時間を置いて再チャレンジ
			sleep 5;
			redo FORK;
		} else {
			
	&error("$@");
			# エラーのためノーマル送信
			$data_ref->{send_type} = 0;
			# HTMLテンプレートオープン
			my $template = &newtemplate();
			# パラメーターを埋める
			$template->param($data_ref);
			# HTML表示
			&printhtml($template,"sjis");
			exit;
		}
	}

};
if($@){
	&error("$@");
	# エラーのためノーマル送信
	$data_ref->{send_type} = 23;
	# HTMLテンプレートオープン
	my $template = &newtemplate();
	# パラメーターを埋める
	$template->param($data_ref);
	# HTML表示
	&printhtml($template,"sjis");
	exit;

}
exit;
