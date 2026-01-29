#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

# クッキーよりセッションデータ取得
my %COOKIE = &getcookie;
my %S = getsession($COOKIE{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

my %FORM;
my $data_ref;
our $SYS;

# フォームよりCSVファイル＆CSVデーター受け取り
my $query = new CGI;
my $filename = $query->param('filename');
$FORM{emailall} = $query->param('emailall');

my $buffer;
if($filename && !$FORM{emailall}){
	while(read($filename, $buffer, 2048)){ 
		$FORM{emailall} .= $buffer; 
		#$file_size ++; 
		#if($file_size > 50){ 
		#	&error("ファイルサイズが大きすぎます。（MAX 100KB）") ;
		#}
	} 
}


$data_ref = &get_admindata();

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
my $i;
my $addnum;
my $emailall;
foreach my $ref (@mailline){

	$ref =~ s/\r//g;
	$ref =~ s/\n//g;
	my $enc = getcode($ref);
	if ($enc ne "euc" && $enc ne "ascii") {
		&jcode::convert(\$ref,'euc',$enc);
	}
	if($ref){
		my @mail = split(/,/,$ref);
		my $row;

		$row->{i} = ++$i;
		$row->{email} = &plantext2html(lc($mail[0]));
		for (1..10) {
			# 文字コード調査
			$row->{"col".$_} = &plantext2html($mail[$_]);
		}
	
		if(!CheckMailAddress(lc($mail[0]))){
			$row->{status} .= "<font color=\"red\">× (メールアドレスエラー)</font><br>";
		}elsif($ZYU{lc($mail[0])}){
			$row->{status} .= "<font color=\"red\">× (重複)</font><br>";
		}
		my $colsdata;
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
			$ZYU{lc($mail[0])}++;
			$emailall .= $ref."\n";
		}
	
		push (@data,$row);
	}
}

$data_ref->{addnum} = $addnum || 0;
$data_ref->{loop} = \@data;
$data_ref->{emailall} = &plantext2html(lc($emailall),"nobr");

$data_ref->{writing} = $SYS->{writing};
$data_ref->{title} = $SYS->{title};
# HTMLテンプレートオープン
my $template = &newtemplate();
# パラメーターを埋める
$template->param($data_ref);
# HTML表示
&printhtml($template,"sjis");
exit;
