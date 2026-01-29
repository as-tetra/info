#!/usr/bin/perl

use lib "./lib/";
require "setup.cgi";
require 'jcode.pl';
require 'mimew.pl';
use strict;
our $SYS;

my %FORM = &form("noexchange", "noencode");
# 管理情報取得
my $rowadmin = &get_admindata("nochange");
# 自動返信メールテンプレート情報取得
my @DATA = &openfile2array("$SYS->{data_dir}form.cgi");
my $rowform;
my @d = split(/\t/, $DATA[0]);
my $i = 0;
foreach my $n (qw(reg_mailtitle reg_mailbody cancel_mailtitle cancel_mailbody type)) {
	$rowform->{$n} = $d[$i];
	$i++;
}

# 送信者のメールアドレス
my $sendername = $rowadmin->{admin_name}.' <'.$rowadmin->{admin_email}.'>';

# sendmailへのパス
my $sendmailpath = $rowadmin->{sendmail_path};

# 不正サイトからの登録禁止
# メールアドレス登録フォームを設置しているURLを書きます。（例：$limit = "http://www.ahref.org/cgi/acmailer/";）
my $limit = '';

#----------------------------------# 
# メールアドレス登録時の文面設定
#----------------------------------# 
my $title;
# メールアドレス登録後のページタイトル
my $title_add = 'メールアドレス登録完了';

# メールアドレス登録時のメール件名
my $ml_subject_add = $rowform->{reg_mailtitle};


#----------------------------------# 
# メールアドレス削除時の文面設定
#----------------------------------# 

# メールアドレス削除後のページタイトル
my $title_del = 'メールアドレス削除完了';

# メールアドレス削除時のメール件名
my $ml_subject_del = $rowform->{cancel_mailtitle};

# 初期設定部分（必須項目）ここまで
# ////////////////////////////////////////////////////////////////////////// #


# ////////////////////////////////////////////////////////////////////////// #
# システム設定
&limit_access($limit) || &error("不正なアクセスです。") if $limit;


# データーファイル名
my $fn_masterdata = "$SYS->{data_dir}mail.cgi";
# ダブルオプト用
my $fn_masterdata_buf = "$SYS->{data_dir}mailbuf.cgi";

$FORM{email} = lc($FORM{email});

# メールアドレス正規表現チェック
if($FORM{mode} ne "autoreg" && !&CheckMailAddress($FORM{email})){
	&error("恐れ入ります。<br>メールアドレスを正しく記入してください。");
}


# データーファイルの読み込み
my @NEWDATA_ORG = &load_file($fn_masterdata) ;
my @NEWDATA_ORG_BUF = &load_file($fn_masterdata_buf) ;

&envetc;

# 管理人へのメールにつける投稿者情報
my ($nowdate, $host, $address);
my $ml_comment_admin=
"
----------------------------------------
DATE              : $nowdate
SERVER_NAME       : $ENV{'SERVER_NAME'}
HTTP_USER_AGENT   : $ENV{'HTTP_USER_AGENT'}
REMOTE_HOST       : $host
REMOTE_ADDR       : $ENV{'REMOTE_ADDR'}
----------------------------------------
";


my $xmailer = '';


# ////////////////////////////////////////////////////////////////////////// #
# メイン処理

# 新規登録、削除、
if (defined $FORM{reg}){
	if ($rowadmin->{double_opt} && $FORM{reg} eq "add") {
		&doubleopt();
	} else {
		&regdel if $FORM{reg} eq "del";
		&regadd if $FORM{reg} eq "add";
	}
} elsif ($FORM{mode} eq "autoreg") {
	&regdoubleopt;
}

&error("不正なアクセスです。");

exit;
# ////////////////////////////////////////////////////////////////////////// #

sub doubleopt{
	my $id = time.$$;
	$id = &md5sum($id);
	my %TIME = &getdatetime();
	
	# エラーチェック
	for(1..10) {
		if ($rowadmin->{"col".$_."checked"}) {
			if ($FORM{"col".$_} eq "") {
				&error($rowadmin->{"col".$_."name"}."は必須項目です。");
			}
		}
	}
	
	chomp @NEWDATA_ORG;
	my $regdata;
	foreach my $line (0..$#NEWDATA_ORG){
		my @data = split(/,/,$NEWDATA_ORG[$line]);
		if($data[0] eq $FORM{email} && $FORM{email}){
			&error("そのアドレスはすでに登録されています。");
		}
	}
	chomp @NEWDATA_ORG_BUF;
	foreach my $line (0..$#NEWDATA_ORG_BUF){
		my @data = split(/,/,$NEWDATA_ORG_BUF[$line]);
		$regdata .= "$NEWDATA_ORG_BUF[$line]\n";
	}
	
	# 文字コード調査
	if ($FORM{force}) {
		# 強制
		for(1..10) {
			&Jcode::convert(\$FORM{"col".$_}, "euc", $FORM{force});
		}
	} else {
		if ($FORM{encode}) {
			my $enc = getcode($FORM{encode});
			if ($enc ne "euc") {
				for(1..10) {
					&Jcode::convert(\$FORM{"col".$_}, "euc", $enc);
				}
			}
		}
	}
	my $formdata = "$id,$TIME{year}$TIME{mon}$TIME{mday},$FORM{email},$FORM{col1},$FORM{col2},$FORM{col3},$FORM{col4},$FORM{col5},$FORM{col6},$FORM{col7},$FORM{col8},$FORM{col9},$FORM{col10}\n";

	#if (&depend_kisyu($formdata)) { &error("登録内容に機種依存文字を使用しないでください。"); }
	$regdata .= $formdata;
	
	# ファイルロック
	my $lfh = &file_lock() || &error("ファイルのロックに失敗しました。しばらくたってからやりなおしてください");
	# カウント数をカウントデータファイルに書き込み
	&reg_file($fn_masterdata_buf,$regdata) || &error("データファイルに書き込めませんでした。<br>お手数ですが管理人にご連絡ください。");
	# ファイルアンロック
	&file_unlock($lfh);
	
	my $ml_comment_add_body ="登録内容\n---------------------------\n";
	$ml_comment_add_body .= "メールアドレス：$FORM{email}\n";
	for(1..10) {
		if ($rowadmin->{"col".$_."name"}) {
			$ml_comment_add_body .= $rowadmin->{"col".$_."name"}."：".$FORM{"col".$_}."\n";
		}
	}
	$ml_comment_add_body .= "\n\n下記URLより本登録を行ってください。\n";
	$ml_comment_add_body .= $rowadmin->{homeurl}."reg.cgi?mode=autoreg&id=$id";
	
	if ($rowadmin->{merumaga_usermail}) {
		# 登録者へメール
		&jmailsend($sendmailpath,$FORM{email},"仮登録完了",$ml_comment_add_body,$sendername,$sendername,$xmailer,$sendername) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	
	&htmlheader2("仮登録完了");
	print "仮登録が完了いたしました。<br>仮登録されたメールアドレスへ自動返信しましたので、メールに記載されているURLから本登録を行ってください。";
	&htmlfooter;
	exit;
}

sub regdoubleopt{
	
	# エラーチェック
	if (!$FORM{id}) { &error("パラメータエラーです。"); }
	
	my $bufdata;
	my $regdata;
	foreach my $ref (@NEWDATA_ORG_BUF) {
		$ref =~ s/\r\n|\r|\n//gi;
		my @ref = split(/,/, $ref);
		if ($FORM{id} eq $ref[0]) {
			$bufdata->{id} = $ref[0];
			$bufdata->{date} = $ref[1];
			$bufdata->{email} = $ref[2];
			for(1..10) {
				$bufdata->{"col".$_} = $ref[($_ + 2)];
			}
		} else {
			$regdata .= $ref."\n";
		}
	}
	if (!$bufdata->{id} || !$bufdata->{email}) { &error("対象のデータ取得に失敗しました。<br>既に登録されているか、仮登録されていません。"); }
	
	# ファイルロック
	my $lfh = &file_lock() || &error("ファイルのロックに失敗しました。しばらくたってからやりなおしてください");
	# カウント数をカウントデータファイルに書き込み
	&reg_file($fn_masterdata_buf,$regdata) || &error("データファイルに書き込めませんでした。<br>お手数ですが管理人にご連絡ください。");
	# ファイルアンロック
	&file_unlock($lfh);
	
	chomp @NEWDATA_ORG;
	$regdata = "";
	foreach my $line (0..$#NEWDATA_ORG){
		my @data = split(/,/,$NEWDATA_ORG[$line]);
		if($data[0] eq $bufdata->{email}){
			&error("そのアドレスはすでに登録されています。");
		}
		$regdata .= "$NEWDATA_ORG[$line]\n";
	}
	my $formdata = "$bufdata->{email},$bufdata->{col1},$bufdata->{col2},$bufdata->{col3},$bufdata->{col4},$bufdata->{col5},$bufdata->{col6},$bufdata->{col7},$bufdata->{col8},$bufdata->{col9},$bufdata->{col10}\n";

	$regdata .= $formdata;
	
	# ファイルロック
	my $lfh = &file_lock() || &error("ファイルのロックに失敗しました。しばらくたってからやりなおしてください");
	# カウント数をカウントデータファイルに書き込み
	&reg_file($fn_masterdata,$regdata) || &error("データファイルに書き込めませんでした。<br>お手数ですが管理人にご連絡ください。");
	# ファイルアンロック
	&file_unlock($lfh);
	
	my $ml_comment_add_body ="登録内容\n---------------------------\n";
	$ml_comment_add_body .= "メールアドレス：$bufdata->{email}\n";
	for(1..10) {
		if ($rowadmin->{"col".$_."name"}) {
			$ml_comment_add_body .= $rowadmin->{"col".$_."name"}."：".$bufdata->{"col".$_}."\n";
		}
	}
	my $ml_comment_add = $rowform->{reg_mailbody};
	$ml_comment_add =~ s/__<<BR>>__/\n/gi;
	$ml_comment_add =~ s/{EMAIL}/$ml_comment_add_body/gi;
	
	if ($rowform->{type} eq "html") {
		$ml_comment_add =~ s/\n/<br>/gi;
		$ml_comment_admin =~ s/\n/<br>/gi;
	}
	
	if ($rowadmin->{merumaga_usermail}) {
		# 登録者へメール
		&jmailsend($sendmailpath,$bufdata->{email},$ml_subject_add,$ml_comment_add,$sendername,$sendername,$xmailer,$sendername, $rowform->{type}) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	if ($rowadmin->{merumaga_adminmail}) {
		# 管理人へメール
		&jmailsend($sendmailpath,$rowadmin->{admin_email},$ml_subject_add.$bufdata->{email},$ml_comment_add.$ml_comment_admin,$sendername,$sendername,$xmailer,$sendername, $rowform->{type}) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	$title=$title_add;

	&htmlheader2("登録完了");
	print "$bufdata->{email}が追加されました。";
	&htmlfooter;
	exit;
}

sub regadd{
	
	# エラーチェック
	for(1..10) {
		if ($rowadmin->{"col".$_."checked"}) {
			if ($FORM{"col".$_} eq "") {
				&error($rowadmin->{"col".$_."name"}."は必須項目です。");
			}
		}
	}
	
	chomp @NEWDATA_ORG;
	my $regdata;
	foreach my $line (0..$#NEWDATA_ORG){
		my @data = split(/,/,$NEWDATA_ORG[$line]);
		if($data[0] eq $FORM{email}){
			&error("そのアドレスはすでに登録されています。");
		}
		$regdata .= "$NEWDATA_ORG[$line]\n";
	}
	# 文字コード調査
	if ($FORM{force}) {
		# 強制
		for(1..10) {
			&Jcode::convert(\$FORM{"col".$_}, "euc", $FORM{force});
		}
	} else {
		if ($FORM{encode}) {
			my $enc = getcode($FORM{encode});
			if ($enc ne "euc") {
				for(1..10) {
					&Jcode::convert(\$FORM{"col".$_}, "euc", $enc);
				}
			}
		}
	}
	my $formdata = "$FORM{email},$FORM{col1},$FORM{col2},$FORM{col3},$FORM{col4},$FORM{col5},$FORM{col6},$FORM{col7},$FORM{col8},$FORM{col9},$FORM{col10}\n";

	#if (&depend_kisyu($formdata)) { &error("登録内容に機種依存文字を使用しないでください。"); }
	$regdata .= $formdata;
	
	# ファイルロック
	my $lfh = &file_lock() || &error("ファイルのロックに失敗しました。しばらくたってからやりなおしてください");
	# カウント数をカウントデータファイルに書き込み
	&reg_file($fn_masterdata,$regdata) || &error("データファイルに書き込めませんでした。<br>お手数ですが管理人にご連絡ください。");
	# ファイルアンロック
	&file_unlock($lfh);
	
	my $ml_comment_add_body ="登録内容\n---------------------------\n";
	$ml_comment_add_body .= "メールアドレス：$FORM{email}\n";
	for(1..10) {
		if ($rowadmin->{"col".$_."name"}) {
			$ml_comment_add_body .= $rowadmin->{"col".$_."name"}."：".$FORM{"col".$_}."\n";
		}
	}
	my $ml_comment_add = $rowform->{reg_mailbody};
	$ml_comment_add =~ s/__<<BR>>__/\n/gi;
	$ml_comment_add =~ s/{EMAIL}/$ml_comment_add_body/gi;
	
	if ($rowform->{type} eq "html") {
		$ml_comment_add =~ s/\n/<br>/gi;
		$ml_comment_admin =~ s/\n/<br>/gi;
	}
	
	if ($rowadmin->{merumaga_usermail}) {
		# 登録者へメール
		&jmailsend($sendmailpath,$FORM{email},$ml_subject_add,$ml_comment_add,$sendername,$sendername,$xmailer,$sendername, $rowform->{type}) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	if ($rowadmin->{merumaga_adminmail}) {
		# 管理人へメール
		&jmailsend($sendmailpath,$rowadmin->{admin_email},$ml_subject_add.$FORM{email},$ml_comment_add.$ml_comment_admin,$sendername,$sendername,$xmailer,$sendername, $rowform->{type}) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	$title=$title_add;

	&htmlheader2("登録完了");
	print "$FORM{email}が追加されました。";
	&htmlfooter;
	exit;
}

sub regdel{

	chomp @NEWDATA_ORG;
	my ($regdata, $delflag);
	foreach my $line (0..$#NEWDATA_ORG){
		my @data = split(/,/,$NEWDATA_ORG[$line]);
		
		if($data[0] ne $FORM{email}){
			$regdata .= "$NEWDATA_ORG[$line]\n";
		}else{
			$delflag = 1;
		}
	}
	
	if(!defined $delflag){
		&error("そのメールアドレスは登録されていません。");
	}
	
	# ファイルロック
	my $lfh = &file_lock() || &error("ファイルのロックに失敗しました。しばらくたってからやりなおしてください");
	# カウント数をカウントデータファイルに書き込み
	&reg_file($fn_masterdata,$regdata) || &error("データファイルに書き込めませんでした。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	# ファイルアンロック
	&file_unlock($lfh);

	my $ml_comment_del_body ="登録削除内容\n---------------------------\n";
	$ml_comment_del_body .="メールアドレス：$FORM{email}\n";
	my $ml_comment_del = $rowform->{cancel_mailbody};
	$ml_comment_del =~ s/__<<BR>>__/\n/gi;
	$ml_comment_del =~ s/{EMAIL}/$ml_comment_del_body/gi;

	if ($rowform->{type} eq "html") {
		$ml_comment_del =~ s/\n/<br>/gi;
		$ml_comment_admin =~ s/\n/<br>/gi;
	}
	
	if ($rowadmin->{merumaga_usermail}) {
		# 登録者へメール
		&jmailsend($sendmailpath,$FORM{email},$ml_subject_del,$ml_comment_del,$sendername,$sendername,$xmailer,$sendername, $rowform->{type}) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	if ($rowadmin->{merumaga_adminmail}) {
		# 管理人へメール
		&jmailsend($sendmailpath,$rowadmin->{admin_email},$ml_subject_del.$FORM{email},$ml_comment_del.$ml_comment_admin,$sendername,$sendername,$xmailer,$sendername, $rowform->{type}) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	$title=$title_del;
	&htmlheader2("削除完了");
	if($delflag){
		print "$FORM{email}は削除されました";
	}
	&htmlfooter;
	exit;
}


# ////////////////////////////////////////////////////////////////////////// #
# ファイル内容読み込み
# &load_file($filename,@line);
# 
# 【引数】
# 1:ファイル名
# 2:取り出したい行番号。配列で複数行指定可能。（省略可）
# 【戻値】
# 成功時：ファイルの内容が一行ずつ配列に入っている。
# 失敗時：0
# 【例】
# @data = &load_file("./test.txt");
# "./test.txt"の内容が一行ずつ@dataに入っている。
# 
# $data = &load_file("./test.txt",3);
# "./test.txt"の内容の3行目が$dataに入る。
# 
# @line = (1,3,5);
# @data = &load_file("./test.txt",@line);
# "./test.txt"の内容の1,3,5行目が@dataに入る。
# 
# ////////////////////////////////////////////////////////////////////////// #
sub load_file{
	my ($filename,@line) = @_;
	my (@LINES, @LINES_S);
	open (IN,$filename) || return undef;
	@LINES = <IN>;
	close (IN);

	if(@line){
		foreach (@line){
			push @LINES_S,$LINES[$_-1] if ($_ >=1 and $_-1 <= $#LINES); 
		}
		return @LINES_S;
	}else{
		return @LINES;
	}
}
# ////////////////////////////////////////////////////////////////////////// #
# ファイル内容書き込み
# &reg_file($filename,$data);
# &reg_file($filename,@data);	# 配列は一つごとに改行が付く。
# 
# 【引数】
# 1:ファイル名
# 2:書き込みたい内容
# 【戻値】
# 成功時：1
# 失敗時：0
# ////////////////////////////////////////////////////////////////////////// #
sub reg_file{
	my ($filename,@data) = @_;
    return 0 if !$filename;
	open (OUT,">$filename") || return 0;
	print OUT @data;
	close (OUT);
    return 1;
}
# ////////////////////////////////////////////////////////////////////////// #
# ファイルロック処理(Perlメモ http://www.din.or.jp/~ohzaki/perl.htm)
# 
# 【例】
# ファイルロック
# $lfh = &file_lock() || &error("ファイルのロックに失敗しました。しばらくたってからやりなおしてください");
# カウント数をカウントデータファイルに書き込み
# &reg_file($fn_data,@DATA) || &error("データファイルに書き込めませんでした。");
# ファイルアンロック
# &file_unlock($lfh);
# 
# ////////////////////////////////////////////////////////////////////////// #
sub file_lock{
	my %lfh = (dir => './lockdir/', basename => 'lockfile', timeout => 60, trytime => 10, @_);
	$lfh{path} = $lfh{dir} . $lfh{basename};

	for (my $i = 0; $i < $lfh{trytime}; $i++, sleep 1) {
		return \%lfh if (rename($lfh{path}, $lfh{current} = $lfh{path} . time));
	}
	opendir(LOCKDIR, $lfh{dir});
	my @filelist = readdir(LOCKDIR);
	closedir(LOCKDIR);
	foreach (@filelist) {
		if (/^$lfh{basename}(\d+)/) {
			return \%lfh if (time - $1 > $lfh{timeout} and
			rename($lfh{dir} . $_, $lfh{current} = $lfh{path} . time));
			last;
		}
	}
	undef;
}
sub file_unlock{
	rename($_[0]->{current}, $_[0]->{path});
}


# ////////////////////////////////////////////////////////////////////////// #
sub envetc{

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$mon++;
	$sec = "0$sec" if $sec < 10;
	$min = "0$min" if $min < 10;
	$hour = "0$hour" if $hour < 10;
	$mday = "0$mday" if $mday < 10;
	$mon = "0$mon" if $mon < 10;
	$year = $year + 1900;
	my $week = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat")[$wday];
	$nowdate = "$year/$mon/$mday($week) $hour:$min:$sec";
	$host = $ENV{'REMOTE_HOST'};
	$address = $ENV{'REMOTE_ADDR'};
	if ($host eq $address) {
		$host = gethostbyaddr(pack('C4',split(/\./,$host)),2) || $address;
	}
}
# ////////////////////////////////////////////////////////////////////////// #

sub htmlheader2{
	my $str = shift;

my $tb_bgcolor="#ffffff";
if($_[0]){$tb_bgcolor=$_[0];}
print <<EOF;
Content-Type: text/html; charset=EUC-JP

<html>
<head>
<title>$str</title>
<meta http-equiv="content-type" content="text/html;charset=EUC-JP">
</head>
<body bgcolor="$tb_bgcolor">
<div align="center"><h3>$str</h3>
EOF
}

# ////////////////////////////////////////////////////////////////////////// #
sub htmlfooter{

print <<EOF;

<br><br>

</div>
</body>
</html>
EOF
}
# ////////////////////////////////////////////////////////////////////////// #

sub md5sum{
	use integer;
	my ($l,$m,@n,$a,$b,$c,$d,@e,$r);
	# Initial values set
	$a=0x67452301;$b=0xefcdab89;$c=0x98badcfe;$d=0x10325476;
	$m=$_[0];
	# Padding
	$l=length $m;
	$m.="\x80"."\x00"x(($l%64<56?55:119)-$l%64);
	$m.=pack "VV",($l<<3)&0xffffffff,$l<<35;
	# Round
	for(0..($l+8)/64){
	@n=unpack 'V16',substr($m,$_<<6,64);
	@e[0..3]=($a,$b,$c,$d);
	$r=($a+$n[0]+0xd76aa478+($b&$c|(~$b&$d)));$a=$b+(($r<<7)|(($r>>25)&0x7f));
	$r=($d+$n[1]+0xe8c7b756+($a&$b|(~$a&$c)));$d=$a+(($r<<12)|(($r>>20)&0xfff));
	$r=($c+$n[2]+0x242070db+($d&$a|(~$d&$b)));$c=$d+(($r<<17)|(($r>>15)&0x1ffff));
	$r=($b+$n[3]+0xc1bdceee+($c&$d|(~$c&$a)));$b=$c+(($r<<22)|(($r>>10)&0x3fffff));
	$r=($a+$n[4]+0xf57c0faf+($b&$c|(~$b&$d)));$a=$b+(($r<<7)|(($r>>25)&0x7f));
	$r=($d+$n[5]+0x4787c62a+($a&$b|(~$a&$c)));$d=$a+(($r<<12)|(($r>>20)&0xfff));
	$r=($c+$n[6]+0xa8304613+($d&$a|(~$d&$b)));$c=$d+(($r<<17)|(($r>>15)&0x1ffff));
	$r=($b+$n[7]+0xfd469501+($c&$d|(~$c&$a)));$b=$c+(($r<<22)|(($r>>10)&0x3fffff));
	$r=($a+$n[8]+0x698098d8+($b&$c|(~$b&$d)));$a=$b+(($r<<7)|(($r>>25)&0x7f));
	$r=($d+$n[9]+0x8b44f7af+($a&$b|(~$a&$c)));$d=$a+(($r<<12)|(($r>>20)&0xfff));
	$r=($c+$n[10]+0xffff5bb1+($d&$a|(~$d&$b)));$c=$d+(($r<<17)|(($r>>15)&0x1ffff));
	$r=($b+$n[11]+0x895cd7be+($c&$d|(~$c&$a)));$b=$c+(($r<<22)|(($r>>10)&0x3fffff));
	$r=($a+$n[12]+0x6b901122+($b&$c|(~$b&$d)));$a=$b+(($r<<7)|(($r>>25)&0x7f));
	$r=($d+$n[13]+0xfd987193+($a&$b|(~$a&$c)));$d=$a+(($r<<12)|(($r>>20)&0xfff));
	$r=($c+$n[14]+0xa679438e+($d&$a|(~$d&$b)));$c=$d+(($r<<17)|(($r>>15)&0x1ffff));
	$r=($b+$n[15]+0x49b40821+($c&$d|(~$c&$a)));$b=$c+(($r<<22)|(($r>>10)&0x3fffff));
	$r=($a+$n[1]+0xf61e2562+($b&$d|(~$d&$c)));$a=$b+(($r<<5)|(($r>>27)&0x1f));
	$r=($d+$n[6]+0xc040b340+($a&$c|(~$c&$b)));$d=$a+(($r<<9)|(($r>>23)&0x1ff));
	$r=($c+$n[11]+0x265e5a51+($d&$b|(~$b&$a)));$c=$d+(($r<<14)|(($r>>18)&0x3fff));
	$r=($b+$n[0]+0xe9b6c7aa+($c&$a|(~$a&$d)));$b=$c+(($r<<20)|(($r>>12)&0xfffff));
	$r=($a+$n[5]+0xd62f105d+($b&$d|(~$d&$c)));$a=$b+(($r<<5)|(($r>>27)&0x1f));
	$r=($d+$n[10]+0x02441453+($a&$c|(~$c&$b)));$d=$a+(($r<<9)|(($r>>23)&0x1ff));
	$r=($c+$n[15]+0xd8a1e681+($d&$b|(~$b&$a)));$c=$d+(($r<<14)|(($r>>18)&0x3fff));
	$r=($b+$n[4]+0xe7d3fbc8+($c&$a|(~$a&$d)));$b=$c+(($r<<20)|(($r>>12)&0xfffff));
	$r=($a+$n[9]+0x21e1cde6+($b&$d|(~$d&$c)));$a=$b+(($r<<5)|(($r>>27)&0x1f));
	$r=($d+$n[14]+0xc33707d6+($a&$c|(~$c&$b)));$d=$a+(($r<<9)|(($r>>23)&0x1ff));
	$r=($c+$n[3]+0xf4d50d87+($d&$b|(~$b&$a)));$c=$d+(($r<<14)|(($r>>18)&0x3fff));
	$r=($b+$n[8]+0x455a14ed+($c&$a|(~$a&$d)));$b=$c+(($r<<20)|(($r>>12)&0xfffff));
	$r=($a+$n[13]+0xa9e3e905+($b&$d|(~$d&$c)));$a=$b+(($r<<5)|(($r>>27)&0x1f));
	$r=($d+$n[2]+0xfcefa3f8+($a&$c|(~$c&$b)));$d=$a+(($r<<9)|(($r>>23)&0x1ff));
	$r=($c+$n[7]+0x676f02d9+($d&$b|(~$b&$a)));$c=$d+(($r<<14)|(($r>>18)&0x3fff));
	$r=($b+$n[12]+0x8d2a4c8a+($c&$a|(~$a&$d)));$b=$c+(($r<<20)|(($r>>12)&0xfffff));
	$r=($a+$n[5]+0xfffa3942+($b^$c^$d));$a=$b+(($r<<4)|(($r>>28)&0xf));
	$r=($d+$n[8]+0x8771f681+($a^$b^$c));$d=$a+(($r<<11)|(($r>>21)&0x7ff));
	$r=($c+$n[11]+0x6d9d6122+($d^$a^$b));$c=$d+(($r<<16)|(($r>>16)&0xffff));
	$r=($b+$n[14]+0xfde5380c+($c^$d^$a));$b=$c+(($r<<23)|(($r>>9)&0x7fffff));
	$r=($a+$n[1]+0xa4beea44+($b^$c^$d));$a=$b+(($r<<4)|(($r>>28)&0xf));
	$r=($d+$n[4]+0x4bdecfa9+($a^$b^$c));$d=$a+(($r<<11)|(($r>>21)&0x7ff));
	$r=($c+$n[7]+0xf6bb4b60+($d^$a^$b));$c=$d+(($r<<16)|(($r>>16)&0xffff));
	$r=($b+$n[10]+0xbebfbc70+($c^$d^$a));$b=$c+(($r<<23)|(($r>>9)&0x7fffff));
	$r=($a+$n[13]+0x289b7ec6+($b^$c^$d));$a=$b+(($r<<4)|(($r>>28)&0xf));
	$r=($d+$n[0]+0xeaa127fa+($a^$b^$c));$d=$a+(($r<<11)|(($r>>21)&0x7ff));
	$r=($c+$n[3]+0xd4ef3085+($d^$a^$b));$c=$d+(($r<<16)|(($r>>16)&0xffff));
	$r=($b+$n[6]+0x04881d05+($c^$d^$a));$b=$c+(($r<<23)|(($r>>9)&0x7fffff));
	$r=($a+$n[9]+0xd9d4d039+($b^$c^$d));$a=$b+(($r<<4)|(($r>>28)&0xf));
	$r=($d+$n[12]+0xe6db99e5+($a^$b^$c));$d=$a+(($r<<11)|(($r>>21)&0x7ff));
	$r=($c+$n[15]+0x1fa27cf8+($d^$a^$b));$c=$d+(($r<<16)|(($r>>16)&0xffff));
	$r=($b+$n[2]+0xc4ac5665+($c^$d^$a));$b=$c+(($r<<23)|(($r>>9)&0x7fffff));
	$r=($a+$n[0]+0xf4292244+($c^($b|~$d)));$a=$b+(($r<<6)|(($r>>26)&0x3f));
	$r=($d+$n[7]+0x432aff97+($b^($a|~$c)));$d=$a+(($r<<10)|(($r>>22)&0x3ff));
	$r=($c+$n[14]+0xab9423a7+($a^($d|~$b)));$c=$d+(($r<<15)|(($r>>17)&0x7fff));
	$r=($b+$n[5]+0xfc93a039+($d^($c|~$a)));$b=$c+(($r<<21)|(($r>>11)&0x1fffff));
	$r=($a+$n[12]+0x655b59c3+($c^($b|~$d)));$a=$b+(($r<<6)|(($r>>26)&0x3f));
	$r=($d+$n[3]+0x8f0ccc92+($b^($a|~$c)));$d=$a+(($r<<10)|(($r>>22)&0x3ff));
	$r=($c+$n[10]+0xffeff47d+($a^($d|~$b)));$c=$d+(($r<<15)|(($r>>17)&0x7fff));
	$r=($b+$n[1]+0x85845dd1+($d^($c|~$a)));$b=$c+(($r<<21)|(($r>>11)&0x1fffff));
	$r=($a+$n[8]+0x6fa87e4f+($c^($b|~$d)));$a=$b+(($r<<6)|(($r>>26)&0x3f));
	$r=($d+$n[15]+0xfe2ce6e0+($b^($a|~$c)));$d=$a+(($r<<10)|(($r>>22)&0x3ff));
	$r=($c+$n[6]+0xa3014314+($a^($d|~$b)));$c=$d+(($r<<15)|(($r>>17)&0x7fff));
	$r=($b+$n[13]+0x4e0811a1+($d^($c|~$a)));$b=$c+(($r<<21)|(($r>>11)&0x1fffff));
	$r=($a+$n[4]+0xf7537e82+($c^($b|~$d)));$a=$b+(($r<<6)|(($r>>26)&0x3f));
	$r=($d+$n[11]+0xbd3af235+($b^($a|~$c)));$d=$a+(($r<<10)|(($r>>22)&0x3ff));
	$r=($c+$n[2]+0x2ad7d2bb+($a^($d|~$b)));$c=$d+(($r<<15)|(($r>>17)&0x7fff));
	$r=($b+$n[9]+0xeb86d391+($d^($c|~$a)));$b=$c+(($r<<21)|(($r>>11)&0x1fffff));
	$a=($a+$e[0])&0xffffffff;
	$b=($b+$e[1])&0xffffffff;
	$c=($c+$e[2])&0xffffffff;
	$d=($d+$e[3])&0xffffffff;}
	unpack('H*',(pack 'V4',$a,$b,$c,$d));
}
1;
