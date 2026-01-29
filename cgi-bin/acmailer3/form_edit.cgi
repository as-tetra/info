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
my @DATA = &openfile2array("$SYS->{data_dir}form.cgi");

my $row;
my @d = split(/\t/,$DATA[0]);
$row->{form_mailtitle} = &plantext2html($d[0]);
$d[1] =~ s/__<<BR>>__/\n/g;
$row->{form_mailbody} = &plantext2html($d[1]);
$row->{form_mailbody_html} = &plantext2html($d[1],"nobr");

$row->{form2_mailtitle} = &plantext2html($d[2]);
$d[3] =~ s/__<<BR>>__/\n/g;
$row->{form2_mailbody} = &plantext2html($d[3]);
$row->{form2_mailbody_html} = &plantext2html($d[3],"nobr");
if ($d[4] eq "html") {
	$row->{html_checked} = " checked ";
} else {
	$row->{regular_checked} = " checked ";
}
my $data_ref = $row;

$data_ref->{oktext} = "変更されました。" if $FORM{okedit};

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
