#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;
our $SYS;

# 管理情報取得
my $row_admin = &get_admindata();

if (!$row_admin->{backnumber_disp}) {
	&error("表示できません。");
}

my %FORM = &form("noexchange");
my @DATA = &openfile2array("$SYS->{data_dir}hist.cgi");

my @SETTING = &openfile2array("$SYS->{data_dir}backnumber_setting.cgi");
my $max = $SETTING[0];

my $data_ref;
my @BACKDATA;

# ソート
@DATA = sort { (split(/\t/,$b))[1] cmp (split(/\t/,$a))[1] } @DATA;

my $count = 0;
foreach my $ref (@DATA) {
	my $row;
	my @d = split(/\t/, $ref);
	my $i = 0;
	foreach my $n (qw(id start_send_date end_send_date mail_title mail_body send_type mail_type backnumber search_colname1 search_text1 search_colname2 search_text2 search_colname3 search_text3 search_colname4 search_text4 search_colname5 search_text5 send)) {
		$row->{$n} = $d[$i];
		$i++;
	}
	$row->{start_send_date} = substr($row->{start_send_date}, 0, 4)."/".substr($row->{start_send_date}, 4, 2)."/".substr($row->{start_send_date}, 6, 2)." ".substr($row->{start_send_date}, 8, 2).":".substr($row->{start_send_date}, 10, 2).":".substr($row->{start_send_date}, 12, 2);
	$row->{end_send_date} = substr($row->{end_send_date}, 0, 4)."/".substr($row->{end_send_date}, 4, 2)."/".substr($row->{end_send_date}, 6, 2)." ".substr($row->{end_send_date}, 8, 2).":".substr($row->{end_send_date}, 10, 2).":".substr($row->{end_send_date}, 12, 2);
	$row->{mail_title} = &plantext2html($row->{mail_title});
	$row->{mail_body} =~ s/__<<BR>>__/\n/gi;
	$row->{send_type} = &plantext2html($row->{send_type});
	$row->{mail_type} = &plantext2html($row->{mail_type});
	
	if (!$row->{backnumber}) { next; }
	
	if ($FORM{id} eq "") { $FORM{id} = $d[0]; }
	if ($row->{send_type} eq "1") {
		$row->{disp_send_type} = "分割";
	} else {
		$row->{disp_send_type} = "ノーマル";
	}
	
	
	# 送信先一覧
	my @send = split(/,/, $row->{send});
	my @senddata;
	foreach my $n (@send) {
		my $data;
		if (!$n) { next; }
		$data->{email} = $n;
		push(@senddata, $data);
	}
	$row->{total_count} = ($#senddata + 1);
	$row->{email_list} = \@senddata;


	# 詳細データ
	if ($FORM{id} eq $row->{id}) {
		foreach my $n (qw(id mail_type start_send_date end_send_date mail_title mail_body send_type)) {
			$data_ref->{$n} = $row->{$n};
			if ($n eq "mail_body") {
				if ($data_ref->{mail_type} eq "plain") {
					$data_ref->{mail_body} = &plantext2html($data_ref->{mail_body});
				} else {
					$data_ref->{mail_body} =~ s/<.*?>//gi;
					$data_ref->{mail_body} = &plantext2html($data_ref->{mail_body}, "onlybr");
				}
			}
		}
	}
	#$row->{mail_body} = &plantext2html($row->{mail_body});
	push(@BACKDATA, $row);
	$count++;
	if ($count >= $max) { last; }
}

#@BACKDATA = sort { $b->{start_send_date} cmp $a->{start_send_date} } @BACKDATA;

if ($data_ref->{mail_type} eq "html") {
	$data_ref->{htmlpreview} = "1";
}

# 送信先一覧
$data_ref->{backnumber_list} = \@BACKDATA;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
