#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

my %FORM = &form();

# クッキーよりセッションデータ取得
if (!$FORM{sid}) { &error('<a href="m_login.cgi">ログイン画面</a>よりログインしなおしてください。'); }
my %COOKIE = &getcookie;
my %S = getsession($FORM{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});
my $data_ref;
our $SYS;
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
