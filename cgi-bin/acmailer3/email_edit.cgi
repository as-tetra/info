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
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
