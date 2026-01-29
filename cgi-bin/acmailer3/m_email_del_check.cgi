#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;
my %FORM;

# フォームよりCSVファイル＆CSVデーター受け取り
my $query = new CGI;
my $filename = $query->param('filename');
$FORM{emailall} = $query->param('emailall');
$FORM{sid} = $query->param('sid');
# クッキーよりセッションデータ取得
if (!$FORM{sid}) { &error('<a href="m_login.cgi">ログイン画面</a>よりログインしなおしてください。'); }
my %COOKIE = &getcookie;
my %S = getsession($FORM{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

my $buffer;
if($filename && !$FORM{emailall}){
	while(read($filename, $buffer, 2048)){ 
		$FORM{emailall} .= $buffer; 
	} 
}

&jcode::convert(\$FORM{emailall}, "euc", "sjis");
my $data_ref = &get_admindata();

my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");
my @data;
my %ZYU;
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = &plantext2html(lc($d[0]));
	$ZYU{$d[0]}++;
	
}

$FORM{emailall} =~ s/\r//;
my @mailline = split(/\n/,$FORM{emailall});
my ($i, $addnum, $emailall);
foreach(@mailline){

	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	if($_){
		my @mail = split(/,/,$_);
		my $row;

		$row->{i} = ++$i;
		$row->{email} = &plantext2html(lc($mail[0]));
		for (1..10) {
			$row->{"col".$_} = &plantext2html($mail[$_]);
		}
	
		if(!CheckMailAddress(lc($mail[0]))){
			$row->{status} .= "<font color=\"red\">× (メールアドレスエラー)</font><br>";
		}elsif(!$ZYU{lc($mail[0])}){
			$row->{status} .= "<font color=\"red\">× (登録無し)</font><br>";
		}
	
		if(!$row->{status}){
			$row->{status} = "◎ (削除可能)";
			++$addnum;
			$ZYU{lc($mail[0])}++;
			$emailall .= $_."\n";
		}
		push (@data,$row);
	}
}

$data_ref->{addnum} = $addnum || 0;
$data_ref->{loop} = \@data;
$data_ref->{emailall} = &plantext2html(lc($emailall),"nobr");

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
