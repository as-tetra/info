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
my $data_ref;
my $row_admin = &get_admindata("nochange");

# 削除日付
if (!$FORM{del_y}) { $FORM{del_y} = "9999"; }
if (!$FORM{del_m}) { $FORM{del_m} = "12"; }
if (!$FORM{del_d}) { $FORM{del_d} = "31"; }
my $deldate = sprintf("%04d%02d%02d", $FORM{del_y}, $FORM{del_m}, $FORM{del_d});

my @DATA = &openfile2array($SYS->{data_dir}."mailbuf.cgi");
my @data;
my $i = 0;
my $regdata;
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{id} = $d[0];
	$row->{date} = $d[1];
	$row->{disp_date} = substr($d[1], 0, 4)."/".substr($d[1], 4, 2)."/".substr($d[1], 6, 2);
	$row->{email} = $d[2];
	for(1..10) {
		$row->{"col".$_} = $d[($_ + 2)];
	}
	if ($deldate >= $row->{date}) {
		$i++;
	} else {
		$regdata .= "$row->{id},$row->{date},$row->{email},$row->{col1},$row->{col2},$row->{col3},$row->{col4},$row->{col5},$row->{col6},$row->{col7},$row->{col8},$row->{col9},$row->{col10}\n";
	}
}

# 書き込み
open (OUT,">$SYS->{data_dir}mailbuf.cgi") || return 0;
print OUT $regdata;
close (OUT);

print "Location: clean_double_opt.cgi?okdel=1&delnum=$i \n\n";
exit;
