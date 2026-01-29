#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});
my $data_ref;
our $SYS;
$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};

# ダブルオプトイン機能を使う場合は掃除画面を表示
my $row = &get_admindata("nochange");
$data_ref->{double_opt} = $row->{double_opt};

# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
