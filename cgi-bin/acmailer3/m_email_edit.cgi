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

if(!$FORM{email}){
	&error("メールアドレスのの指定が正しくありません。");
}
my $data_ref = &get_admindata();
my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");

foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);

	if($d[0] && $d[0] eq $FORM{email}){
		$data_ref->{email} = &plantext2html($d[0]);
		for(1..10) {
			$data_ref->{"col".$_} = &plantext2html($d[$_]);
		}
	}
}

if(!$data_ref->{email}){
	&error("該当するデータは存在しません。");
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
