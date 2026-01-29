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
my $data_ref;

# カラム取得
my (@cols);
foreach(1..10){
	my $row;
	my $d = "col".$_."name";
	if (!$row_admin->{$d}) { next; }
	$row->{col} = $_;
	$row->{colname} = $row_admin->{$d};
	push(@cols,$row);
}
$data_ref->{col_list} = \@cols;

# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
