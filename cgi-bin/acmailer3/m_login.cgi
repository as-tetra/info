#!/usr/bin/perl

our $SYS;
use lib "./lib/";
require "./lib/setup.cgi";
use strict;

# 管理情報取得
my $data_ref = &get_admindata();

my $template;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};

if ($data_ref->{login_id} && $data_ref->{login_pass}) {
	# HTMLテンプレートオープン
	$template = &newtemplate();
} else {
	print "Content-type: text/html; charset=EUC-JP\n\n";
	print "パソコン用ログイン画面より初期設定を行ってください。";
	exit;
}
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
