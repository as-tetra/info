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
my @DATA = &openfile2array("$SYS->{data_dir}backnumber_setting.cgi");

my $data_ref;
my @d = split(/\t/,$DATA[0]);
$data_ref->{disp_num} = $d[0];

$data_ref->{oktext} = "変更されました。" if $FORM{okedit};

# reg.cgiの場所
my $regcgi = $ENV{REQUEST_URI};
if ($regcgi =~ /(.*)\/[^\/]*backnumber_setting\.cgi.*$/) {
	$regcgi = $1."/backnumber.cgi";
}
$data_ref->{http_host} = $ENV{HTTP_HOST};
$data_ref->{request_uri} = $regcgi;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
