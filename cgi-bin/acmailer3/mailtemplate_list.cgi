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
my @DATA = &openfile2array("$SYS->{data_dir}template.cgi");

my @TEMPLATEDATA;
foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	$row->{id} = $d[0];
	$row->{template_name} = &plantext2html($d[1]);
	$row->{mail_title} = &plantext2html($d[2]);
	$row->{mail_body} = $d[3];
	$row->{mail_body} =~ s/__<<BR>>__/<br>/gi;
	$row->{default} = $d[4];
	if ($row->{default}) {
		$row->{default_checked} = " checked ";
	}
	push(@TEMPLATEDATA, $row);
}

my $data_ref;

# 送信先一覧
$data_ref->{template_list} = \@TEMPLATEDATA;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
