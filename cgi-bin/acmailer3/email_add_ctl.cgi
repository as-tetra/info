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


my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");
my @data;
my %ZYU;
foreach(@DATA){
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = &plantext2html($d[0]);

	$ZYU{$d[0]}++;
	
}

$FORM{emailall} =~ s/\r//;
my @mailline = split(/\n/,$FORM{emailall});
my ($i, $addnum, $colsdata, $emailall);

foreach(@mailline){

	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	if($_){
		my @mail = split(/,/,$_);
		my $row;

		$row->{i} = ++$i;
		$row->{email} = &plantext2html($mail[0]);
		for (1..10) {
			$row->{"col".$_} = &plantext2html($mail[$_]);
		}
	
		if(!CheckMailAddress($mail[0])){
			$row->{status} .= "<font color=\"red\">× (メールアドレスエラー)</font><br>";
		}elsif($ZYU{$mail[0]}){
			$row->{status} .= "<font color=\"red\">× (重複)</font><br>";
		}
	
		foreach(1..10){
			my $col = "col".$_;
			my $colname = "col".$_."name";
			if($data_ref->{$col."checked"} && ($row->{$col} eq "")){
				$row->{status} .= "<font color=\"red\">× (必須「$data_ref->{$colname}」)</font><br>";
			}
			#$FORM{$col} =~ s/\t//g;
			#$FORM{$col} =~ s/"//g;
			#$FORM{$col} =~ s/'//g;
			$row->{$col} =~ s/,/，/g;
			$colsdata .= ",$row->{$col}";
		}
	
		if(!$row->{status}){
			$row->{status} = "◎ (登録可能)";
			++$addnum;
			$ZYU{$mail[0]}++;
			$emailall .= $_."\n";
		}else{
			&error("処理を中断しました。<br>操作中にデータファイルの更新があった可能性があります。<br>$row->{email}<br>$row->{status}");
		}
	
	}
}

my $regdata;
#ファイルオープン
open(IN, "+< $SYS->{data_dir}mail.cgi") || &error("データファイルのオープンに失敗しました。");
flock(IN, 2);
my @MAIL = <IN>;
foreach(@MAIL){

	$_ =~ s/\r//g;
	$_ =~ s/\n//g;
	my @mail =split(/,/,$_);
	if($mail[0]){
		$regdata .= $_."\n";
	}
}
$regdata = $regdata . $emailall;
seek(IN, 0, 0);
print(IN $regdata);
truncate(IN,tell(IN));
close(IN);

# ページジャンプ
print "Location: $SYS->{homeurl_ssl}email_list.cgi?okadd=1\n\n";
exit;
