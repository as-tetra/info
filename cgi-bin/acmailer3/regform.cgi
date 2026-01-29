#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;
# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

my %FORM = &form;
my $data_ref;
my $row_admin = &get_admindata("nochange");


my $regcgi = $ENV{REQUEST_URI};
$data_ref->{form_url} = $row_admin->{homeurl}."reg.cgi";
$data_ref->{counter_url} = $row_admin->{homeurl}."counter.cgi";

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
