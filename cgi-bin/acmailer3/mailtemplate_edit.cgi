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

if ($FORM{id} =~ /[^0-9]/ || !$FORM{id}) { &error("パラメータエラーです。"); }

my $data_ref;
foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	
	if ($d[0] ne $FORM{id}) { next; }
	
	$data_ref->{id} = $d[0];
	$data_ref->{template_name} = &plantext2html($d[1]);
	$data_ref->{mail_title} = &plantext2html($d[2]);
	$data_ref->{mail_body} = $d[3];
	$data_ref->{mail_body} =~ s/__<<BR>>__/\n/gi;
	$data_ref->{default} = $d[4];
}

my $row_admin = &get_admindata("nochange");

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


$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
