#!/usr/bin/perl

my $myfilepath = '/virtual/calamari/public_html/www.as-tetra.info/cgi-bin/acmailer3/';
use POSIX;
use MIME::Base64;
use File::Copy;
require $myfilepath.'lib/jcode.pl';
require $myfilepath.'lib/mimew.pl';

my $mode = $ARGV[0];

our $SYS;
$SYS->{data_dir} = $myfilepath."data/";

# 管理情報取得
my $rowadmin = &get_admindata();

my %FORM;
# メール内容取得
my $v = getmaildata();

$FORM{email} = $v->{email};
$FORM{body} = $v->{body};

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

# データーファイル名
my $fn_masterdata = "$SYS->{data_dir}mail.cgi";
# ダブルオプトイン用
my $fn_masterdata_buf = "$SYS->{data_dir}mailbuf.cgi";

# データーファイルの読み込み
my @NEWDATA_ORG = &load_file($fn_masterdata) ;
my @NEWDATA_ORG_BUF = &load_file($fn_masterdata_buf) ;
&envetc;
# 管理人へのメールにつける投稿者情報
my ($nowdate, $host, $address);
my $ml_comment_admin= "";

my $xmailer = '';

# 登録
if ($mode eq "reg") {
	if ($rowadmin->{double_opt}) {
		&doubleopt();
	} else {
		&regadd();
	}
} elsif ($mode eq "del") {
	&regdel();
}

exit;

sub doubleopt{
	my $id = time.$$;
	$id = &md5sum($id);
	my %TIME = &getdatetime();
	
	# 項目取得
	for(my $i = 1; $i <= 10; $i++) {
		my $target = $rowadmin->{"col".$i."name"};
		my @body = split(/\r\n|\r|\n/, $FORM{body});
		foreach my $ref (@body) {
			if ($ref =~ /$target(\:)(.*)/i) {
				$FORM{"col".$i} = $2;
			}
		}
	}
	
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
			&error("そのアドレスはすでに登録されています。$data[0]:$FORM{email}");
		}
	}
	chomp @NEWDATA_ORG_BUF;
	foreach my $line (0..$#NEWDATA_ORG_BUF){
		my @data = split(/,/,$NEWDATA_ORG_BUF[$line]);
		$regdata .= "$NEWDATA_ORG_BUF[$line]\n";
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
		if ($rowadmin->{"col".$_."name"} !~ /^\(項目[0-9]{1,2}\)$/) {
			$ml_comment_add_body .= $rowadmin->{"col".$_."name"}."：".$FORM{"col".$_}."\n";
		}
	}
	$ml_comment_add_body .= "\n\n下記URLより本登録を行ってください。\n";
	$ml_comment_add_body .= $rowadmin->{homeurl}."reg.cgi?mode=autoreg&id=$id";
	
	if ($rowadmin->{merumaga_usermail}) {
		# 登録者へメール
		&jmailsend($sendmailpath,$FORM{email},"仮登録完了",$ml_comment_add_body,$sendername,$sendername,$xmailer,$sendername) || &error("メールアドレスの送信に失敗しました。<br>お手数ですが管理人「$sendername」にご連絡ください。");
	}
	
}


sub regadd{
	
	# 項目取得
	for(my $i = 1; $i <= 10; $i++) {
		my $target = $rowadmin->{"col".$i."name"};
		my @body = split(/\r\n|\r|\n/, $FORM{body});
		foreach my $ref (@body) {
			if ($ref =~ /$target(\:)(.*)/i) {
				$FORM{"col".$i} = $2;
			}
		}
	}
	
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
			&error("そのアドレスはすでに登録されています。$data[0]:$FORM{email}");
		}
		$regdata .= "$NEWDATA_ORG[$line]\n";
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
		if ($rowadmin->{"col".$_."name"} !~ /^\(項目[0-9]{1,2}\)$/) {
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
}


sub getmaildata {
	my %TIME = &getdatetime();
	my $message;
	my $boundary;
	my $email;
	# 一度メールを読み込み保存する
	while (<STDIN>) {
		$message .=  $_;
	}
	
	&jcode::convert(\$message,"euc");

	# ヘッダーと本文に分解&配列化
	my $mail_head = $message;
	$mail_head =~ s/\n\n(.*)//s;
	my $mail_body = $1;
	my @mail_head = split(/\n/,$mail_head);
	my @mail_body = split(/\n/,$mail_body);
	my $kind;
	
	my ($email_f, $subject_f, $body_f);
	foreach (@mail_head) {
		if (/^(.*): (.*)$/i) {
			$kind = $1;
		}
		# 送信元メールアドレス
		if ($kind =~ /from/i && !$email_f) {
			$email = $_;
			$mail_f = 1;
		}

		# 件名取得
		if (/Subject:(.*)/i) {
			$kind = "subject";
			$subject = $1;
			$subject_f = 1;
		}
		
		
		# boundary取得
		if(/(.*)boundary\=\"(.*)\"/ && $email_f && $subject_f && $body_f) {
			$kind = "boundary";
			$boundary = $2;
		}
		
		
	}

	# DOCOMOとAU対策 "asdf..asdf."@docomo.ne.jpみたいなアドレスできた場合"を外す
	if ($email =~ /[^\"]*(\")([^\"]*)\"(\@.*)$/) {
		$email = $2.$3;
	}
	
	# メールアドレス取得
	$email = lc(&getmailaddr($email));


	my $bound_count = 0;
	my $flag;
	my $chk_3gp;
	my @data;
	my $bodydata;
	foreach (@mail_body) {
		if ($boundary) {
			if(/(.*)$boundary(.*)/) {
				$bound_count++;
				next;
			}
			if ($bound_count == 1) {
				$bodydata .= $_."\n";
			}
		} else {
			$bodydata .= $_."\n";
		}
	
	}
	# 件名Bエンコードをデコード
	my $lws = '(?:(?:\x0D\x0A|\x0D|\x0A)?[ \t])+';
	my $ew_regex = '=\?ISO-2022-JP\?B\?([A-Za-z0-9+/]+=*)\?=';
	$subject =~ s/($ew_regex)$lws(?=$ew_regex)/$1/gio;
	$subject =~ s/$lws/ /go;
	$subject =~ s/$ew_regex/decode_base64($1)/egio;
	&jcode::convert(\$subject, 'euc', 'jis');
	
	my $v;
	
	
	$v->{email} = $email;
	$v->{subject} = $subject;
	$v->{body} = $bodydata;
	
	return $v;
	
}

# 時間取得
sub getdatetime{
	my %TIME;
	my $time = shift;
	my $nn = shift;
	if(!$time){
		$time = time;
	}
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
	my $year4;
	my $year2;
	$mon++;
	$year4 = $year + 1900;
	$year2 = $year - 100;
	if(!$nn){
		$sec = "0$sec" if $sec < 10;
		$min = "0$min" if $min < 10;
		$hour = "0$hour" if $hour < 10;
		$mday = "0$mday" if $mday < 10;
		$mon = "0$mon" if $mon < 10;
		$year2 = "0$year2" if $year2 < 10;
	}
	
	my $week =  ("Sun","Mon","Tue","Wed","Thu","Fri","Sat")[$wday];
	$TIME{year}		= $year4;
	$TIME{year2}	= $year2;
	$TIME{mon}		= $mon;
	$TIME{mday}		= $mday;
	$TIME{week}		= $week;
	$TIME{hour}		= $hour;
	$TIME{min}		= $min;
	$TIME{sec}		= $sec;
	$TIME{time}		= $time;
	$TIME{nowdate}	= "$year/$mon/$mday($week) $hour:$min:$sec";
	return %TIME;
}

sub jmailsend{

	my $sendmail=$_[0];
	my $to=$_[1];
	my $subject=$_[2];
	my $body=$_[3];
	my $from=$_[4];
	my $replyto=$_[5];
	my $xmailer=$_[6];
	my $returnpath = $_[7];
	my $mail_type = $_[8];
	
	if ($mail_type eq "html") {
		$mail_type = "text/html";
	} else {
		$mail_type = "text/plain";
	}

	#未入力エラー
	if (!$sendmail){return 0;}
	if (!$to){return 0;}
	if (!$from){return 0;}
	
	# to,replyto,returnpathはメールアドレスのみ抽出
	my $to_m = &getmail($to);
	$replyto = &getmail($replyto);
	$returnpath = &getmail($returnpath);

	#sendmailの起動
	if ($SYS->{qmail}) {
		open(MAIL,"| $sendmail -f $returnpath $to") || return undef;
	} else {
		open(MAIL,"| $sendmail $to") || return undef;
	}

	#件名、本文をJISに変換
	&jcode::convert(\$subject, "jis");
	&jcode::convert(\$body, "jis");

	#メールHEADER定義
	print MAIL "Return-Path: $returnpath\n" if $returnpath;
	print MAIL "X-Mailer: acmailer3.0 http://www.ahref.org/\n";
	print MAIL "MIME-Version: 1.0\n";
	print MAIL "Reply-To: $replyto\n" if $replyto;
	print MAIL &mimeencode("To: $to\n");
	print MAIL &mimeencode("From: $from\n");
	print MAIL &mimeencode("Subject: $subject\n");
	print MAIL "Content-Transfer-Encoding: 7bit\n";
	print MAIL "Content-Type: $mail_type\; charset=\"ISO-2022-JP\"\n\n";

	#メール本文定義
	print MAIL $body;

	close(MAIL);
	return 1;
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
	
}



sub getmail{
	my $mail = shift;
	my $mail_regex = q{([\w|\!\#\$\%\'\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)\@([\w|\!\#\$\%\'\(\)\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)};
	if($mail =~ /$mail_regex/o){
		$mail =~ s/($mail_regex)(.*)/$1/go;		# メールアドレスの最後以降を削除
		$mail =~ s/(.*)[^\w|\!\#\$\%\'\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+($mail_regex)/$2/go;		# メールアドレスまでを削除
	}
	return $mail;
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
	my %lfh = (dir => $myfilepath.'lockdir/', basename => 'lockfile', timeout => 60, trytime => 10, @_);
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



# 管理情報取得
sub get_admindata {
	my $opt = shift;
	my @DATA = &openfile2array($SYS->{data_dir}."admin.cgi");
	my @d = split(/\t/,$DATA[0]);
	my $data;
	$data->{admin_name} = &plantext2html($d[0]);
	$data->{login_id} = &plantext2html($d[1]);
	$data->{login_pass} = &plantext2html($d[2]);
	$data->{admin_email} = &plantext2html($d[3]);
	for (1..10) {
		my $change = "(項目$_)";
		if ($opt eq "nochange") { $change = ""; }
	
		$data->{"col".$_."name"} = &plantext2html($d[($_ + 3)]) || $change;
		$data->{"col".$_."checked"} = &plantext2html($d[($_ + 13)]);
	}
	$data->{title} = &plantext2html($d[24]);
	$data->{sendmail_path} = &plantext2html($d[25]);
	$data->{send_type} = &plantext2html($d[26]);
	$data->{divnum} = &plantext2html($d[27]);
	$data->{backnumber_disp} = $d[28];
	$data->{counter_disp} = $d[29];
	$data->{homeurl} = $d[30];
	$data->{merumaga_usermail} = $d[31];
	$data->{merumaga_adminmail} = $d[32];
	$data->{ssl} = $d[33];
	$data->{divwait} = $d[34];
	$data->{qmail} = $d[35];
	$data->{rireki_email} = $d[36];
	$data->{mypath} = $d[37];
	$data->{double_opt} = $d[38];
	return $data;
}


# HTML特殊文字エスケープ＆改行を<br>に変換
sub plantext2html{
	my $text = shift;
	my $type = shift;
	
	#type一覧
	#onlybr = \nを<BR>に変換のみ
	#nobr = \nを<BR>に変換しない
	#それ以外 = HTMLタグをエンティティー化
	
	if($type eq "onlybr"){
		$text =~ s/\n/<br>/g;
		return $text;
	}

	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/\"/&quot;/g;

	if($type ne "nobr"){
		$text =~ s/\n/<br>/g;
	}

	return $text;
}
sub openfile2array{
	my $filepath = shift;
	my @DATA;
	&error("$filepathのオープンに失敗しました。$!") unless -e $filepath;
	
	#データファイルオープン
	open (IN,$filepath) || &error("データファイルのオープンに失敗しました。$!");
	flock(IN,1);
	my @DATA_ORG = <IN>;
	close (IN);

	#改行取り除き
	foreach(@DATA_ORG){
		$_ =~ s/\r\n//g;
		$_ =~ s/\r//g;
		$_ =~ s/\n//g;
		
		#from_to($html_data, 'utf8', 'shiftjis');
		#&Jcode::convert(\$_, "euc");
		if($_){
			push(@DATA,$_);
		}
	}
	return @DATA;

}

sub error {
	my $str = shift;
	#print STDERR "$str";
	if (!$FORM{email}) { $FORM{email} = $rowadmin->{admin_email}; }
	&jmailsend($sendmailpath,$FORM{email},"エラー",$str,$sendername,$sendername,$xmailer,$sendername);
	exit;
}
sub getmailaddr{
	my $mail = shift;
	# メールアドレス正規表現
	$mail_regex = q{([\w|\!\#\$\%\'\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)\@([\w|\!\#\$\%\'\(\)\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)};
	if($mail =~ /$mail_regex/o){
		$mail =~ s/($mail_regex)(.*)/$1/go;		# メールアドレスの最後以降を削除
		$mail =~ s/(.*)[^\w|\!\#\$\%\'\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+($mail_regex)/$2/go;		# メールアドレスまでを削除
	}
	return $mail;
}

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
