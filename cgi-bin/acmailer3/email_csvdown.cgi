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
my $data_ref = &get_admindata();


my $mail = "E-MAIL,$data_ref->{col1name},$data_ref->{col2name},$data_ref->{col3name},$data_ref->{col4name},$data_ref->{col5name},$data_ref->{col6name},$data_ref->{col7name},$data_ref->{col8name},$data_ref->{col9name},$data_ref->{col10name}\n";

#フォーム送信先一覧
my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");

foreach(@DATA){
	$mail .= $_."\n";
}

&jcode::convert(\$mail, "sjis", "euc");
my %DATE = &getdatetime;

my $size = length $mail;
print "Content-Type: application/octet-stream\n"; 
print "Content-Disposition: attachment; filename=maildata$DATE{year}$DATE{mon}$DATE{mday}.csv\n"; 
print "Content-Length: $size\n\n"; 

print $mail;
exit;

exit;
