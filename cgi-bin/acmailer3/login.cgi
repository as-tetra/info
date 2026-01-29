#!/usr/bin/perl

our $SYS;
use lib "./lib/";
require "./lib/setup.cgi";
use strict;

# 管理情報取得
my $data_ref = &get_admindata();

my $template;

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};

if ($data_ref->{login_id} && $data_ref->{login_pass}) {
	# HTMLテンプレートオープン
	$template = &newtemplate();
} else {
	# SENDMAILパスを探す
	if (-e "/usr/sbin/sendmail") {
		$data_ref->{sendmail_path} = "/usr/sbin/sendmail";
	} elsif (-e "/usr/lib/sendmail") {
		$data_ref->{sendmail_path} = "/usr/lib/sendmail";
	}
	# CGI設置URLを抽出
	my $regcgi = $ENV{REQUEST_URI};
	if ($regcgi =~ /(.*)\/[^\/]*login\.cgi.*$/) {
		$regcgi = $1;
		if ($data_ref->{ssl}) {
			$data_ref->{form_url} = "https://".$ENV{HTTP_HOST}.$1."/";
		} else {
			$data_ref->{form_url} = "http://".$ENV{HTTP_HOST}.$1."/";
		}
	}
	# HTMLテンプレートオープン
	$template = &newtemplate("init.tmpl");
}
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
