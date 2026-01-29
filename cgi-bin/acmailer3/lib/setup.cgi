# ACMAILER3
# 08/04/18 Ver3.0βリリース
# 08/04/18 Ver3.1β
# 修正
# ・バックナンバーにログインチェックがあるのを外す
# ・メール送信確認画面でのプレビュー数は全件→10件に変更
# ・送信ボタンに二度押し禁止チェック導入
# ・送信確認画面上部の送信件数が絞込みを行っても全件表示される不具合修正
# ・送信データのセッションの持ち方を変更。セッションデータを200分の1に縮小
# ・送信確認画面ではHTML送信でもプレビューはタグを表示するよう修正
# ・同じく送信履歴でもHTMLメールをテキストにして表示するよう修正
# ・同じくバックナンバーでもHTMLメールをテキストにして表示するよう修正
# ・本文に'が入っていた場合、送信プレビューのところでjavascriptエラーがでる不具合修正
# ・通常送信の場合、休憩処理を入れていたが無効に
# ・配信メールテンプレート・自動返信テンプレートの登録・修正でタブコードを半角スペースへ置換する修正
# ・分割送信時の待ち秒数設定を追加
# ・メール送信確認・履歴詳細画面・バックナンバーにてHTMLメールの場合プレビューリンクを追加
# ・各種設定より「SSLを使用する」の項目を削除。入力されたCGI設置URLはフォームタグ作成とバックナンバーのアクセス制御に使用
# 
# 08/04/23 Ver.3.11β
# ・不正にwriting.cgiを消した場合InternalServerErrorになるのを修正
# ・メール一覧に検索機能追加
# ・送信履歴に検索機能追加
# ・QMAILかどうかの設定を追加
# ・送信履歴にメールアドレスも記憶するかどうかの設定を追加
# ・HTMLメール時、送信履歴・バックナンバーにてタグを取り除いた形で見せるよう変更
# ・メール送信不完了を取得できるようステータスを保持。
# ・履歴に送信件数を持つように変更
# 08/05/20 Ver.3.12β
# ・差出人名に使用できない文字列を設定
# ・送信時の差出人名に&が入っているとおかしくなるバグ修正
# 08/06/20 Ver.3.13β
# 修正
# ・reg.cgiで送信元フォームに文字コード調査用の項目が設置されていなければエラーになるのを修正
# ・reg.cgiでメール内容が文字化けするのを修正
# ・履歴参照で表示件数を変更すると正しくソートされない不具合修正
# 追加機能
# ・携帯用メール送信画面
# ・空メール送信登録モジュール
# ・ダブルオプトイン機能
# ・自動返信メールHTML機能
# 08/06/24 Ver.3.20β
# ・主にユーザビリティ変更
# ・ダブルオプトインの仮登録データ掃除画面追加
# ・テンプレート画面下にラジオボタンのクリアボタン追加
# ・送信画面のテンプレートセレクトボックスにデフォルト設定されているものは（デフォルト）と表示して選択状態に
# ・送信確認画面下に最大１０件まで表示という言葉を明記
# ・携帯送信画面でforkテストをし、成功すればバックグランド処理、失敗すればノーマルのメールアドレスを表示しない送信方法に変更
# ・各種設定でSSL(https)の設定をできるように修正
# ・ダブルオプトイン機能のIDをMD5にし、強化。
# 08/07/18 Ver.3.21β
# ・reg.cgiで項目名がでない不具合を修正
# ・同じくautoreg.plでも項目名がでない不具合を修正

use File::Basename;
use HTML::Template;
use POSIX;
use CGI;
use Jcode;
use Crypt::RC4;
require 'mimew.pl';
require 'jcode.pl';
use strict;


our $SYS;
$SYS->{tmpl_error_file} = "./tmpl/error.tmpl";
$SYS->{data_dir} = "./data/";
$SYS->{dir_session} = "./session/";
$SYS->{sendmail} = '/usr/sbin/sendmail';

my @DATA = &openfile2array("$SYS->{data_dir}admin.cgi");
my @d = split(/\t/,$DATA[0]);
$SYS->{admin_name} = &plantext2html($d[0]);
$SYS->{login_id} = &plantext2html($d[1]);
$SYS->{login_pass} = &plantext2html($d[2]);
$SYS->{admin_email} = &plantext2html($d[3]);
$SYS->{title} = &plantext2html($d[24]);

$SYS->{homeurl} = $d[30];
$SYS->{writing} = &writing_check();
$SYS->{qmail} = $d[35];

open (IN,"./data/writing.cgi") || return 1;
while(<IN>){
	$SYS->{writing_code} .= $_;
}
close (IN);

# 以下サブルーチン集
sub form {
	my $buffer;
	my %FORM;
	my $noexchange = shift;
	my $noencode = shift;
	# フォームからの入力
	if ($ENV{'REQUEST_METHOD'} eq "POST") {
		read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
	}else {
		$buffer = $ENV{'QUERY_STRING'};
	}
	my @pairs = split(/&/,$buffer);
	foreach (@pairs) {
		my ($name, $value) = split(/=/, $_);
		$value =~ tr/+/ /;
		$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
		$name =~ tr/+/ /;
		$name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
		$name =~ s/\r\n/\n/g;
		$name =~ s/\r/\n/g;
		$value =~ s/\r\n/\n/g;
		$value =~ s/\r/\n/g;

		if ($noencode ne "noencode") {
			&jcode::convert(\$name,'euc','sjis');
			&jcode::convert(\$value,'euc','sjis');
		}
		
		if($noexchange ne "noexchange"){
			$name =~ s/;/；/g;
			$value =~ s/;/；/g;
			$name =~ s/,/，/g;
			$value =~ s/,/，/g;
			$name =~ s/&/＆/g;
			$value =~ s/&/＆/g;
			$name =~ s/=/＝/g;
			$value =~ s/=/＝/g;
			$name =~ s/'/’/g;
			$value =~ s/'/’/g;
			$name =~ s/"/”/g;
			$value =~ s/"/”/g;
		}
		
		$FORM{$name} = $value;
	
	}
	return %FORM;

}

#各種エラーチェック関数
sub errorcheck(){
	my $str = shift;
	my $type = shift;
	my $com = shift;
	
	# type = 1 入力がなければエラー
	if($type == 1){
		
		if(!$str){
			&error($com);
		}
		
	# type = 2 メールアドレス正規表現チェック
	}elsif($type == 2){
		
		if(!CheckMailAddress($str)){
			&error($com);
		}
		
	}
	return 1;
}

sub openfile2array{
	my $filepath = shift;
	my @DATA;
	&error("$filepathのオープンに失敗しました。") unless -e $filepath;
	
	#データファイルオープン
	open (IN,$filepath) || &error("データファイルのオープンに失敗しました。");
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

sub CheckMailAddress {

	my $mailadr = shift;
	my $mail_regex = q{(^[\w|\!\%\'\=\-\^\\\~\+\*\.\?\/]+)\@([\w|\!\#\$\%\'\(\)\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)(\.\w+)+$};
	
	#シェルスクリプト展開時のエラー回避
	if ($mailadr =~ /\`/){return undef;}
	if ($mailadr =~ /^-/){return undef;}
	if ($mailadr =~ /\)/){return undef;}
	if ($mailadr =~ /\(/){return undef;}
	if ($mailadr =~ /\"/){return undef;}
	if ($mailadr =~ /\'/){return undef;}
	if ($mailadr =~ /\;/){return undef;}
	if ($mailadr =~ /\|/){return undef;}
	if ($mailadr =~ /&/){return undef;}
	if ($mailadr =~ /\\/){return undef;}
	
	
	if ($mailadr =~ /$mail_regex/ ){
		return 1;
	}else{
		return undef;
	}
}
# 不正アクセス防止
sub limit_access{
	my $filename = shift;
	my @url = split(/,/, $filename);
	my $ng = 1;
	my $ng_url;
	foreach my $n (@url) {
		my $ref_url = $SYS->{homeurl}.$n if $n;
		$ref_url =~ s/^http(.+)/http\(s\)\?$1/;
		
		if ($ref_url) {
			if (!$ENV{'HTTP_REFERER'} || $ENV{'HTTP_REFERER'} !~ /^$ref_url/) {
				$ng_url = $ref_url;
			} elsif ($ENV{'HTTP_REFERER'} =~ /^$ref_url/) {
				$ng = 0;
			}
		}
	}
	if ($ng) { &error("不正なアクセスです。<br>$ng_url"); }
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
# plantext2htmlの逆
sub html2plantext{
	my $text = shift;
	my $br = shift;
	if ($text){
		$text =~ s/&amp;/&/g;
		$text =~ s/&lt;/</g;
		$text =~ s/&gt;/>/g;
		$text =~ s/&quot;/\"/g;
		$text =~ s/<br>/\n/g unless $br;
	}
	return $text;
}

#コンマを付加
sub comma{

	my $d = shift;
	my $opt = shift;
	
	if(!$d){$d=0;}
	
	if($d !~ /^[0-9]+$/){ return $d; }
	
	$d=~s/\G((?:^-)?\d{1,3})(?=(?:\d\d\d)+(?!\d))/$1,/g;
	if(!$opt){
		return $d."円";
	}
	if($opt eq "not"){
		return $d;
	}
	if($opt eq "zeronull"){
		if($d){
			return $d."円";
		}else{
			return "&nbsp;";
		}
	}
	# return "\\".$d;
}
# ////////////////////////////////////////////////////////////////////////// #
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
# ////////////////////////////////////////////////////////////////////////// #
# HTMLテンプレートオープン
sub newtemplate{
	my $templatedir = "";		# テンプレートのあるディレクトリ
	my $templatesuffix = '.tmpl';	# テンプレートファイルの拡張子
	my $fn_template = shift;
	# CGIとテンプレートとのファイル名の関連づけ
	if (!$fn_template){
 		my ($base,$path,$suffix) = fileparse($0);
		$base =~ s/\.cgi$//;
		$fn_template = $base.$templatesuffix;
	}
	
	my $template = HTML::Template->new(filename => $fn_template , die_on_bad_params => 0, path => [ './tmpl/']);

	return $template;
}

# ////////////////////////////////////////////////////////////////////////// #
sub getmail{
	my $mail = shift;
	my $mail_regex = q{([\w|\!\#\$\%\'\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)\@([\w|\!\#\$\%\'\(\)\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+)};
	if($mail =~ /$mail_regex/o){
		$mail =~ s/($mail_regex)(.*)/$1/go;		# メールアドレスの最後以降を削除
		$mail =~ s/(.*)[^\w|\!\#\$\%\'\=\-\^\`\\\|\~\[\{\]\}\+\*\.\?\/]+($mail_regex)/$2/go;		# メールアドレスまでを削除
	}
	return $mail;
}
# テンプレートを使用しないエラー関数（システムエラー）
sub syserror {
	my $errortext=$_[0];
	
	print "Content-type: text/html; charset=UTF-8;\n\n";
	print "<html><head><title>SYSTEM ERROR</title></head>\n";
	print "<body>\n";
	print "SYSTEM ERROR<br><br>$errortext<br>";
	print "</body></html>\n";
	exit;

}
# テンプレートを使用したエラー関数
sub error{
	my $errordata = shift;
	my $data_ref;
	$data_ref->{ERRDATA} = $errordata;
	$data_ref->{writing} = $SYS->{writing};
	$data_ref->{title} = $SYS->{title};
	
	if(!-e $SYS->{tmpl_error_file}){
		&syserror("エラーテンプレートの設定が正しくありません");
	}
	
	
	#携帯振り分け
	my $mobile;
	if($ENV{'HTTP_USER_AGENT'} =~ /^(docomo\/1)/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^(L-mode)/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^(ASTEL)/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^J\-PHONE/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^Vodafone/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^SoftBank/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^MOT\-/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^(docomo\/2)/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^(KDDI)/i){
		$mobile = 1;
	}elsif($ENV{'HTTP_USER_AGENT'} =~ /^up\.browser/i){
		$mobile = 1;
	}
	
	if ($mobile) {
		$SYS->{tmpl_error_file} = "m_error.tmpl";
	}
	
	
	# HTMLテンプレートオープン
	my $template = &newtemplate($SYS->{tmpl_error_file});
	# パラメーターを埋める
	$template->param(
		$data_ref
	);
	# HTML表示
	&printhtml($template,"sjis");
	exit;
}


# HTMLテンプレート出力
# 第２引数があればSJISで出力、なければUTF8
# SJISでの出力の場合、呼び出し元でJcodeをインクルードしておくこと。
sub printhtml{
	my $template = shift;
	my $mozicode = shift;
	if ($mozicode){
		print "Content-Type: Text/html;charset=Shift_JIS\n";
		print "Pragma: no-cache\n";
		print "Cache-Control: no-cache\n";
		print "Expires: Thu, 01 Dec 1994 16:00:00 GMT\n\n";
		my $html_data = $template->output;
		&jcode::convert(\$html_data, 'sjis', 'euc');
		
		print $html_data
	}else{
		print "Content-Type: Text/html;charset=UTF-8\n\n";
		print $template->output;
	}
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

# セッションID暗号化
sub encrypt_id {
	my $id = shift;
	my @id;
	my $newid;
	my $x = substr($id , -1);
	my $x2;
	my @ids;
	if($x == 0){$x2 = 10;}
	else{$x2=$x;}
	$id = ($id +1) * 97 * ($x2);
	@ids = $id =~ /[\x00-\x7F]/og;
	for(reverse @ids){
		$newid = $newid.$_;
	}
	$newid = $newid.$x;
	return $newid;
}

# セッションID復元化
sub decrypt_id {
	my $str = shift;
	my $newstr;
	my @strs;
	my $x = substr($str , -1 ,1,"");
	my $x2;
	if($x == 0){$x = 10;}
	else{$x2=$x;}
	@strs = $str =~ /[\x00-\x7F]/og;
	for(reverse @strs){
		$newstr = $newstr.$_;
	}
	$newstr = ($newstr / (97 * $x)) -1;
	return $newstr;
}


# クッキーからデーターを取得
sub getcookie{
	my %COOKIE = ();
	my @cookie_pairs = split(/;/,$ENV{'HTTP_COOKIE'});

	if ($ENV{'HTTP_COOKIE'}){
		foreach (@cookie_pairs){
			$_ =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack("C", hex($1))/eg;
			my ($name, $value) = split(/=/, $_);
			$name =~ s/ //g;
			$value =~ s/ //g;
			$COOKIE{$name}=$value;
		}
	}else{
		return undef;
	}
	return %COOKIE;
}
# セッションからデータを取得
# 入力：クッキーからの暗号化されているセッションID
# 出力：連想配列
sub getsession{
	my $sid = shift;
	my %S;
	my $fn_session;
	my $sdata;
	my @s;
	
	$sid = decrypt_id($sid);
	$fn_session = $SYS->{dir_session}.".".$sid.".cgi";
	open (IN,"$fn_session") || return undef;
	while(<IN>){
		$sdata .= $_;
	}
	close (IN);

	&jcode::convert(\$sdata, "euc");
	@s = split(/;/,$sdata);

	foreach (@s){
		my ($l,$r) = split(/=/,$_);
		if($l){
			$S{$l} = $r;
		}
	}
	return %S;
}
sub setsession{
	my $sid = shift;
	my %S = @_;
	my $sdata;
	foreach (keys %S){
		$sdata .= "$_=$S{$_};";
	}

	$sid = decrypt_id($sid);
	my $fn_session = $SYS->{dir_session}.".".$sid.".cgi";

#	&error("$sid<hr>");
	# セッション保存
	if(!-e $fn_session){
		# 新規の場合
		open (F,"> $fn_session") or &error($fn_session);
		print(F $sdata);
		close(F);
		chmod (0666,"$fn_session");
	}else{
		# 上書きの場合
		open(F, "+< $fn_session") or &error($fn_session);
		flock(F, 2);
		truncate(F, 0);
		seek(F, 0, 0);
		print(F $sdata);
		close(F);
	}
}


# ログインチェック
sub logincheck {

	my($login_id,$login_pass)=@_;

	# 入力チェック
	if(!$login_id || !$login_pass){
		&error("認証に失敗しました。お手数ですが再びログインし直してください。<br><br><a href=\"login.cgi\">ログイン画面</a>");
	}
	my $LOGIN;
	if($SYS->{login_id} eq $login_id && $SYS->{login_pass} eq $login_pass){ 
		$LOGIN->{login_id} = $login_id;
		$LOGIN->{login_pass} = $login_pass;
		return $LOGIN;
	}else{
		# 認証失敗
		&error("認証に失敗しました。お手数ですが再びログインし直してください。<br><br><a href=\"login.cgi\">ログイン画面</a>");
	}
}

# Shift_JIS用全角対応substr
sub z_substr {
	my ($s,$p,$l,$o) = @_;
	##
	#Encode::from_to($s, "utf8","cp932");
	$s =~ s/(.)/$1\0/g;
	$s =~ s/([\x81-\x9f\xe0-\xfc])\0(.)\0/$1$2\0\0/g;
	$s = $l eq '' ? substr($s,$p*2):substr($s,$p*2,$l*2);
	if ($o) { $s =~ s/^\0\0/ /; $s =~ s/.[^\0]$/ /;}
	$s =~ tr/\0//d;
	##
	#Encode::from_to($s, "cp932","utf8");
	return $s;
}

sub urlencode{
	my $str = shift;
	$str=~s/([^0-9A-Za-z_ ])/'%'.unpack('H2',$1)/ge;
	$str=~s/\s/+/g;
	return $str;
}

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

# 機種依存文字の有無確認
# 有→1、無→0　を返す
sub depend_kisyu{
	my $name = shift;
	
	if($name){
		# 機種依存文字発見のためにsjisに変換
		&jcode::convert(\$name, "sjis","euc");
		#Encode::from_to($name, "euc-jp","cp932");
		&jcode::h2z_sjis(\$name);
		if (&get_windows_char( \$name )) {
			return 1;
		}
	}
}
sub get_windows_char {
	my ($str)=@_;
	my ($ascii, $sjis_twoBytes, $sjis_pattern);
	&init_windows_char($ascii, $sjis_twoBytes, $sjis_pattern);	# 1回目のみテーブルを初期化
	join '', $$str =~ m/\G(?:$ascii|$sjis_twoBytes)*?((?:$sjis_pattern)+)/og;
}
sub htmlheader{


my $tb_bgcolor="#ffffff";
if($_[0]){$tb_bgcolor=$_[0];}
print <<EOF;
Content-Type: text/html; charset=EUC-JP

<html>
<head>
<title>送信中</title>
<meta http-equiv="content-type" content="text/html;charset=EUC-JP">
<SCRIPT language="JavaScript">
<!--
var set=0;
function nidoosi() {
	if(set==0){
		set=1;
	}else{
		alert("二度押しはいけません。\\nしばらくそのままお待ちください。");
		return false
	}
}
function delcheck() {
	f = confirm("削除してよろしいですか？");
	return f
}


//-->
</SCRIPT>
</head>
<body>
<div align="center"><h3>送信中</h3>
EOF
}

# ////////////////////////////////////////////////////////////////////////// #
sub htmlfooter{

# ///////////////////////////////////////////////////////////////// #
# 【重要】著作権表示について
# 
# AHREF フリーCGIではご使用にあたり著作権表示をお願いしております。
# 著作権表示をはずすにはこちらをご覧ください。
# ■著作権非表示について
# http://www.ahref.org/cgityosaku.html
# ///////////////////////////////////////////////////////////////// #

	my $write = '<div align="center">
<!-- ■■■■■■著作権について（重要！）■■■■■■ -->
<!-- 本システムは、AHREF(エーエイチレフ)に無断で下記著作権表示を削除・改変・非表示にすることは禁止しております -->
<!-- 著作権非表示に関しては、こちらをご確認下さい。 -->
<!-- http://www.ahref.org/cgityosaku.html -->
<!-- ■■■■■■■■■■■■■■■■■■■■■■■■ -->
<font size="-2" color=#999999>メルマガ配信CGI <a href="http://www.ahref.org/" title="メルマガ配信CGI ACMAILER" target="_blank">ACMAILER</a> Copyright (C) 2008 <a href="http://www.ahref.org/" target="_blank" title="エーエイチレフ">ahref.org</a> All Rights Reserved.
</font>
</div>';
	if ($SYS->{writing}) { $write = ""; }
	
print <<EOF;

<br><br>
$write
</body>
</html>
EOF
}


sub init_windows_char {
	
	my $ascii = $_[0];
	my $sjis_twoBytes = $_[1];
	my $sjis_pattern = $_[2];
	
	my %conv_table;
	my %conv_data = (
		
		0x8740=>		# 13区
		'(1) (2) (3) (4) (5) (6) (7) (8) (9)
		(10) (11) (12) (13) (14) (15) (16)
		(17) (18) (19) (20) I II III IV
		V VI VII VIII IX X . ミリ
		キロ センチ メートル グラム トン アール ヘクタール リットル
		ワット カロリー ドル セント パーセント ミリバール ページ mm
		cm km mg kg cc m^2 〓 〓 〓 〓 〓 〓 〓 〓 平成',
		
		0x8780=>		# 13区
		'" ,, No. K.K. Tel (上) (中) (下) (左)
		(右) (株) (有) (代) 明治 大正 昭和
		≒ ≡ ∫ ∫ Σ √ ⊥
		∠ Ｌ △ ∵ ∩ ∪',
		
		0xEEEF=>		# 92区
		q{i ii iii iv v vi vii viii ix x ¬ | ' ''},
		
		0xFA40=>		# 115区
		q{i ii iii iv v vi vii viii ix x
		I II III IV V VI VII VIII IX X ¬ | ' ''
		(株) No. Tel ∵ },
	);
	foreach (keys %conv_data){
		my $base_code = $_;
		Encode::from_to($base_code, "utf-8", "cp932");
		my @chars = split(/\s+/,$conv_data{$_});
		foreach (@chars){		# ↓ tr/\0//d は１バイトの半角カナ用
			my $char_code;
			($char_code = pack('C*',$base_code/256,$base_code%256)) =~ tr/\0//d;
			my $text = $_;
			Encode::from_to($text, "utf-8", "cp932");
			$conv_table{$char_code} = $text;
			$base_code++;
		}
	}
	$ascii = '[\x00-\x7F]';
	$sjis_twoBytes = '[\x81-\x9F\xE0-\xFC][\x40-\x7E\x80-\xFC]';
	# ↓半角カナと13区(\x87),89-92区(\xED\xEE),115-119区(\xFA-\xFC)
	$sjis_pattern='[\xA0-\xDF]|[\x87\xED\xEE\xFA-\xFC][\x40-\x7E\x80-\xFC]';
	Encode::from_to($ascii, "utf-8", "cp932");
	Encode::from_to($sjis_twoBytes, "utf-8", "cp932");
	Encode::from_to($sjis_pattern, "utf-8", "cp932");
	
	$_[0] = $ascii;
	$_[1] = $sjis_twoBytes;
	$_[2] = $sjis_pattern;
	return %conv_table;
}

sub writing_check {
	my $fn = "./data/writing.cgi";
	my $fn_enc = "./data/enc.cgi";
	if (! -e $fn_enc) { return 0; }
	my $key;
	open (IN,"$fn") || return undef;
	while(<IN>){
		$key .= $_;
	}
	close (IN);
	my $enc;
	my @enc;
	my $key_fre;
	open (IN,"$fn_enc") || return undef;
	while(<IN>){
		$enc .= $_;
	}
	close (IN);
	my @enc = split(/\r\n|\r|\n/, $enc);
	my $i = 0;
	foreach my $n (qw(key enc)) {
		$key_fre->{$n} = $enc[$i];
		$i++;
	}
	if ($key_fre->{key} && $key_fre->{enc} && $key) {
		my $dec = &RC4_dec_hex($key_fre->{key}, $key_fre->{enc});
		if ($key eq $dec) { return 1; }
	}
	return 0;
}

sub RC4_dec_hex {
	my($pass, $enchex) = @_;

	my(@encbin) = ();
	while (length($enchex) > 0) {
		push(@encbin, pack("h2", $enchex));
		$enchex = substr($enchex, 2);
	}
	my($dec) = RC4($pass, join('', @encbin));
	return $dec;
}

1;
