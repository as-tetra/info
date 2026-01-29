#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
use strict;

our $SYS;
my %FORM = &form("noexchange");
# クッキーよりセッションデータ取得
if (!$FORM{sid}) { &error('<a href="m_login.cgi">ログイン画面</a>よりログインしなおしてください。'); }
my %COOKIE = &getcookie;
my %S = getsession($FORM{sid});
my $LOGIN = logincheck($S{login_id},$S{login_pass});

my $data_ref;
my $row_admin = &get_admindata();

$FORM{mail_title} = $S{mail_title};
$FORM{mail_body} = $S{mail_body};
$FORM{mail_title} =~ s/__<<equal>>__/\=/gi;
$FORM{mail_body} =~ s/__<<equal>>__/\=/gi;
$FORM{mail_title} =~ s/__<<semicolon>>__/;/gi;
$FORM{mail_body} =~ s/__<<semicolon>>__/;/gi;

if ($S{sender_data} eq "") {
	&error("送り先がありません。");
}

if(!$row_admin->{admin_name}){
	&error("メール差出人名を設定してください。<a href=\"admin_edit.cgi\">→設定</a>");
}
if(!$row_admin->{admin_email}){
	&error("メール差出人メールアドレスを設定してください。<a href=\"admin_edit.cgi\">→設定</a>");
}
if(!CheckMailAddress($row_admin->{admin_email})){
	&error("メール差出人メールアドレスが正しくありません。<a href=\"admin_edit.cgi\">→設定</a>");
}

if(!-x $row_admin->{sendmail_path}){
	&error("sendmailのパスが正しくありません。こちらより<a href=\"admin_edit.cgi\">設定</a>してください。");
}

if (!$FORM{mail_title}) { &error("件名を入力してください。"); }
if (!$FORM{mail_body}) { &error("本文を入力してください。"); }
$data_ref = $row_admin;

#件名
$data_ref->{mail_title} = &plantext2html($FORM{mail_title},"nobr");
$data_ref->{mail_title_html} = &plantext2html($FORM{mail_title});

#本文
$data_ref->{mail_body} = &plantext2html($FORM{mail_body},"nobr");
$data_ref->{mail_body_html} = &plantext2html($FORM{mail_body});

# 送信先一覧
my @DATA = split(/\n/, $S{sender_data});
my @data;
my $i;
foreach(@DATA){
	if (!$_) { next; }
	my $row;
	my @d = split(/,/,$_);
	$row->{email} = $d[0];
	$row->{subject} = $FORM{mail_title};
	$row->{body} = $FORM{mail_body};
	for (1..10) {
		$row->{"col".$_} = &plantext2html($d[$_]);
	}
	# 置換作業
	for(1..10) {
		my $n = "col".$_;
		$row->{subject} =~ s/{COL$_}/$row->{$n}/gi;
		$row->{body} =~ s/{COL$_}/$row->{$n}/gi;
	}
	if ($FORM{mail_type} eq "plain") {
		$row->{subject} =~ s/__<<BR>>__/\n/gi;
		$row->{body} =~ s/__<<BR>>__/\n/gi;
	} else {
		$row->{subject} =~ s/__<<BR>>__/<BR>/gi;
		$row->{body} =~ s/__<<BR>>__/<BR>/gi;
	}
	$row->{subject} =~ s/{EMAIL}/$row->{email}/gi;
	$row->{body} =~ s/{EMAIL}/$row->{email}/gi;
	$row->{num} = ($i + 1);
	push (@data,$row);
	$i++;
}

#配信テスト
if($FORM{send_test}){
	&sendmail_admin(@data);
	exit;
}

# メール送信(強制バックグラウンド処理)
#if ($row_admin->{send_type} == 1 && $row_admin->{divnum} =~ /^[0-9]+$/ && $row_admin->{divnum} > 0){
#	&sendmail_div(@data);
if(!$FORM{send_type}){
	&sendmail(@data);
}elsif($FORM{send_type} == 2){

	# バックグランド処理
	my @NEWDATA_ORG = @data;
	
	if (!$FORM{starttime}) {
		my %STIME = &getdatetime();
		$FORM{starttime} = "$STIME{year}$STIME{mon}$STIME{mday}$STIME{hour}$STIME{min}$STIME{sec}";
	}
	

	# 履歴データに書き込み------------------------------------------
	my $regdata;
	my $id = time.$$;
	#ファイルオープン
	open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
	flock(IN, 2);
	my @DATA;
	my @LINES_ORG = <IN>;
	foreach(@LINES_ORG){
		$_ =~ s/\r\n//g;
		$_ =~ s/\r//g;
		$_ =~ s/\n//g;
		if($_){
			$regdata .= $_."\n";
		}
	}
	$regdata .= $id."\t";	# ID
	$regdata .= $FORM{starttime}."\t";	# 送信開始時間
	$regdata .= "\t";	# 送信終了時間
	$regdata .= "$FORM{mail_title}\t";	# 件名
	my $regbody = $FORM{mail_body};
	$regbody =~ s/\r\n|\r|\n/__<<BR>>__/gi;
	$regdata .= "$regbody\t";	# 本文
	$regdata .= $row_admin->{send_type}."\t";	# 送信タイプ
	$regdata .= $FORM{mail_type}."\t";			# HTMLメールかPLAINメール
	$regdata .= "\t";	# バックナンバー
	for(1..5) {
		$regdata .= $S{"search_colname".$_}."\t";	# 絞込みカラム
		$regdata .= $S{"search_text".$_}."\t";		# 絞込みテキスト
	}
	$regdata .= "\t";	# 送信アドレス
	$regdata .= "\t";	# 送信件数
	$regdata .= "1";
	$regdata .= "\n";
	truncate(IN, 0);
	seek(IN, 0, 0);
	print(IN $regdata);
	close(IN);
	#------------------------------------------------------------------
	

	my $pid;
	# 処理をバックグラウンドでする
	FORK: {
		if ($pid = fork) {
			print "Location:m_email_send_finish.cgi?sid=$FORM{sid} \n\n";
			
			# STDOUTを閉じないと、apacheが終了statusを返さないらしい。よって、ブラウザが開放されない。
			close(STDOUT);
			close(STDERR);
			close(STDIN);
			# 子プロセスの終了を待っていないと、子がZombieになってまうらしい
			wait;
		} elsif (defined $pid) {
			# バックグラウンド処理
		
			close(STDOUT);
			close(STDERR);
			close(STDIN);
			my $c = 1;
			my $sendername = &html2plantext($row_admin->{admin_name}).'<'.&html2plantext($row_admin->{admin_email}).'>';
			my @hist;
			foreach my $row (@NEWDATA_ORG){
				my $return = 1;
				$return = &jmailsend($row_admin->{sendmail_path},$row->{email},$row->{subject},$row->{body},$sendername,$sendername,"",$sendername, $FORM{mail_type});
				if ($return){
					my $hist;
					$hist->{email} = $row->{email};
					push(@hist, $hist);
				}else{
					
				}
				$c++;
			}
			
			# 履歴データに最終書き込み
			my $regdata;
			my %TIME = &getdatetime();
	
			#ファイルオープン
			open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
			flock(IN, 2);
			my @DATA;
			my @LINES_ORG = <IN>;
			foreach(@LINES_ORG){
				$_ =~ s/\r\n//g;
				$_ =~ s/\r//g;
				$_ =~ s/\n//g;
				if($_){
					my @d  = split(/\t/, $_);
					if ($id ne $d[0]) {
						$regdata .= $_."\n";
					} else {
						$regdata .= $d[0]."\t";	# ID
						$regdata .= $d[1]."\t";	# 送信開始時間
						$regdata .= "$TIME{year}$TIME{mon}$TIME{mday}$TIME{hour}$TIME{min}$TIME{sec}\t";	# 送信終了時間
						$regdata .= "$d[3]\t";	# 件名
						$regdata .= "$d[4]\t";	# 本文
						$regdata .= $d[5]."\t";	# 送信タイプ
						$regdata .= $d[6]."\t";			# HTMLメールかPLAINメール
						$regdata .= "1\t";	# バックナンバー
						$regdata .= "$d[8]\t$d[9]\t$d[10]\t$d[11]\t$d[12]\t$d[13]\t$d[14]\t$d[15]\t$d[16]\t$d[17]\t";
						# 送信先
						if ($row_admin->{rireki_email}) {
							foreach my $ref (@hist) {
								$regdata .= $ref->{email}.",";
							}
							$regdata .= "\t".($c - 1);
						} else {
							$regdata .= "\t".($c - 1);
						}
						$regdata .= "\t2\n";
					}
				}
			}
			truncate(IN, 0);
			seek(IN, 0, 0);
			print(IN $regdata);
			close(IN);
			
			# セッションクリア
			&clear_mailsession();
			exit;
		} elsif ($! =~ /No more process/) {
			# プロセスが多すぎる場合、時間を置いて再チャレンジ
			sleep 5;
			redo FORK;
		} else {
			# ここにくることはない
			die "Can't fork: $\n";
		}
	}
}
&error("システムエラーです。送信タイプを各種設定で設定してください。");
exit;


sub sendmail{
	my @NEWDATA_ORG = @_;
	
	if (!$FORM{starttime}) {
		my %STIME = &getdatetime();
		$FORM{starttime} = "$STIME{year}$STIME{mon}$STIME{mday}$STIME{hour}$STIME{min}$STIME{sec}";
	}
	
	

	# 履歴データに書き込み------------------------------------------
	my $regdata;
	my $id = time.$$;
	#ファイルオープン
	open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
	flock(IN, 2);
	my @DATA;
	my @LINES_ORG = <IN>;
	foreach(@LINES_ORG){
		$_ =~ s/\r\n//g;
		$_ =~ s/\r//g;
		$_ =~ s/\n//g;
		if($_){
			$regdata .= $_."\n";
		}
	}
	$regdata .= $id."\t";	# ID
	$regdata .= $FORM{starttime}."\t";	# 送信開始時間
	$regdata .= "\t";	# 送信終了時間
	$regdata .= "$FORM{mail_title}\t";	# 件名
	my $regbody = $FORM{mail_body};
	$regbody =~ s/\r\n|\r|\n/__<<BR>>__/gi;
	$regdata .= "$regbody\t";	# 本文
	$regdata .= $row_admin->{send_type}."\t";	# 送信タイプ
	$regdata .= $FORM{mail_type}."\t";			# HTMLメールかPLAINメール
	$regdata .= "\t";	# バックナンバー
	for(1..5) {
		$regdata .= $S{"search_colname".$_}."\t";	# 絞込みカラム
		$regdata .= $S{"search_text".$_}."\t";		# 絞込みテキスト
	}
	$regdata .= "\t";	# 送信アドレス
	$regdata .= "\t";	# 送信件数
	$regdata .= "1";
	$regdata .= "\n";
	truncate(IN, 0);
	seek(IN, 0, 0);
	print(IN $regdata);
	close(IN);
	#------------------------------------------------------------------
	
	$|=1;

	&htmlheader;
	
	print '</div><br><div align="center"><div style="width:600;padding:4px 5px;border-color:#FF9900;border-style:double;background:#FFFFFF;">'."\r\n\r\n";
	
	# グラフ生成
	print &make_graph_html()."<br>";
	
	print "<font color=\"#ff0000\"><b>送信中です・・・</b></font><br><br>";
	my $c = 1;
	my $sendername = &html2plantext($row_admin->{admin_name}).'<'.&html2plantext($row_admin->{admin_email}).'>';
	my @hist;
	foreach my $row (@NEWDATA_ORG){
		my $return = 1;
		$return = &jmailsend($row_admin->{sendmail_path},$row->{email},$row->{subject},$row->{body},$sendername,$sendername,"",$sendername, $FORM{mail_type});
		if ($return){
			
			my $hist;
			$hist->{email} = $row->{email};
			push(@hist, $hist);
		}else{
			print '<font size="-1">'."$c:"."<font color=\"#ff0000\">送信エラー($row->{email})</font></font><br>\n";
		}
		
		my $bar = int(($c / ($#NEWDATA_ORG + 1)) * 50);
		my $per = int(($c / ($#NEWDATA_ORG + 1)) * 100);
		if ($bar > 50) { $bar = 50; }
		if ($per > 100) { $per = 100; }
		
		$c++;
	}
	print "<br><font color=\"#ff0000\"><b>送信完了しました。</b></font><br>";
	print "<div align=\"center\">";
	print "<br><a href=\"m_email_send.cgi?sid=$FORM{sid}\">戻る</a></div></div></div>";

	&htmlfooter;
	
	# 履歴データに最終書き込み
	my $regdata;
	my %TIME = &getdatetime();
	
	#ファイルオープン
	open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
	flock(IN, 2);
	my @DATA;
	my @LINES_ORG = <IN>;
	foreach(@LINES_ORG){
		$_ =~ s/\r\n//g;
		$_ =~ s/\r//g;
		$_ =~ s/\n//g;
		if($_){
			my @d  = split(/\t/, $_);
			if ($id ne $d[0]) {
				$regdata .= $_."\n";
			} else {
				$regdata .= $d[0]."\t";	# ID
				$regdata .= $d[1]."\t";	# 送信開始時間
				$regdata .= "$TIME{year}$TIME{mon}$TIME{mday}$TIME{hour}$TIME{min}$TIME{sec}\t";	# 送信終了時間
				$regdata .= "$d[3]\t";	# 件名
				$regdata .= "$d[4]\t";	# 本文
				$regdata .= $d[5]."\t";	# 送信タイプ
				$regdata .= $d[6]."\t";			# HTMLメールかPLAINメール
				$regdata .= "1\t";	# バックナンバー
				$regdata .= "$d[8]\t$d[9]\t$d[10]\t$d[11]\t$d[12]\t$d[13]\t$d[14]\t$d[15]\t$d[16]\t$d[17]\t";
				# 送信先
				if ($row_admin->{rireki_email}) {
					foreach my $ref (@hist) {
						$regdata .= $ref->{email}.",";
					}
					$regdata .= "\t".($c - 1);
				} else {
					$regdata .= "\t".($c - 1);
				}
				$regdata .= "\t2\n";
			}
		}
	}
	truncate(IN, 0);
	seek(IN, 0, 0);
	print(IN $regdata);
	close(IN);

	# セッションクリア
	&clear_mailsession();
	print "<meta http-equiv=\"REFRESH\" content=\"0;URL=m_email_send_finish.cgi?sid=$FORM{sid}\">\n";
	exit;
}

sub sendmail_div{
	my @NEWDATA_ORG = @_;
	
	my $waittime = $row_admin->{divwait};
	my $start = $FORM{"start"};
	my $end = $start + $row_admin->{divnum};

	my $c = 0;
	my $sendername = &html2plantext($row_admin->{admin_name}).'<'.&html2plantext($row_admin->{admin_email}).'>';
	
	if (!$FORM{starttime}) {
		my %STIME = &getdatetime();
		$FORM{starttime} = "$STIME{year}$STIME{mon}$STIME{mday}$STIME{hour}$STIME{min}$STIME{sec}";
		
		$FORM{id} = time.$$;
		# 履歴データに書き込み
		my $regdata;
		#ファイルオープン
		open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
		flock(IN, 2);
		my @DATA;
		my @LINES_ORG = <IN>;
		foreach(@LINES_ORG){
			$_ =~ s/\r\n//g;
			$_ =~ s/\r//g;
			$_ =~ s/\n//g;
			if($_){
				$regdata .= $_."\n";
			}
		}
		$regdata .= $FORM{id}."\t";	# ID
		$regdata .= $FORM{starttime}."\t";	# 送信開始時間
		$regdata .= "\t";	# 送信終了時間
		$regdata .= "$FORM{mail_title}\t";	# 件名
		my $regbody = $FORM{mail_body};
		$regbody =~ s/\r\n|\r|\n/__<<BR>>__/gi;
		$regdata .= "$regbody\t";	# 本文
		$regdata .= $row_admin->{send_type}."\t";	# 送信タイプ
		$regdata .= $FORM{mail_type}."\t";			# HTMLメールかPLAINメール
		$regdata .= "\t";	# バックナンバー
		for(1..5) {
			$regdata .= $S{"search_colname".$_}."\t";	# 絞込みカラム
			$regdata .= $S{"search_text".$_}."\t";		# 絞込みテキスト
		}
		$regdata .= "\t";	# 送信アドレス
		$regdata .= "\t";	# 送信件数
		$regdata .= "1";	# ステータス
		$regdata .= "\n";
		truncate(IN, 0);
		seek(IN, 0, 0);
		print(IN $regdata);
		close(IN);
	}
	
	my $data_num = ($#NEWDATA_ORG + 1);
	$| = 1;
	print "Content-Type: text/html; charset=EUC-JP\n\n";
	print "<html>\n";
	print "<head>\n";
	print "<title>分割送信中</title>\n";
	print "<meta http-equiv=\"content-type\" content=\"text/html;charset=EUC-JP\">\n";
	print "<br><div align=\"center\" id=\"message\"><b>ただいま送信中・・・</b><br><br>しばらくそのままでおまちください！";
	print "<br><br></div><div align=\"center\" id=\"now\">$end / $data_num</div>";
	print '<div align="center"><div style="width:600;padding:4px 5px;border-color:#FF9900;border-style:double;background:#FFFFFF;">';
	
	# グラフ生成
	print &make_graph_html()."<br>";
	my $bar = int((($start + 1) / ($#NEWDATA_ORG + 1)) * 50);
	my $per = int((($start + 1) / ($#NEWDATA_ORG + 1)) * 100);
	if ($bar > 50) { $bar = 50; }
	if ($per > 100) { $per = 100; }
	print '<script type="text/javascript">parent.setProgress('.$per.','.$bar.');</script><br>';
	
	
	foreach my $row (@NEWDATA_ORG){
		if($c >= $start && $c < $end){
			my $return = 1;
			$return = &jmailsend($row_admin->{sendmail_path},$row->{email},$row->{subject},$row->{body},$sendername,$sendername,"",$sendername, $FORM{mail_type});
			if ($return){
				print ('<font size="-1">'.($c + 1).":"."$row->{email}</font><br>\n");
			}else{
				print (($c + 1).":"."<font color=\"#ff0000\">送信エラー($row->{email})</font><br>\n");
			}
			my $bar = int((($c + 1) / ($#NEWDATA_ORG + 1)) * 50);
			my $per = int((($c + 1) / ($#NEWDATA_ORG + 1)) * 100);
			if ($bar > 50) { $bar = 50; }
			if ($per > 100) { $per = 100; }
			print '<script type="text/javascript">parent.setProgress('.$per.','.$bar.');</script>';
			print '<script type="text/javascript"><!--
	document.getElementById(\'now\').innerHTML = "'.($c + 1)." / ".$data_num.'";
	// --></script>';
		}
		$c++;

	}

	if($data_num > $end){
		print "<meta http-equiv=\"REFRESH\" content=\"$waittime;URL=m_email_send_ctl.cgi?start=$end&starttime=$FORM{starttime}&mail_type=$FORM{mail_type}&id=$FORM{id}&sid=$FORM{sid}\">\n";
	}
	print "</head>\n";
	print "<body bgcolor=\"#FFFFFF\">\n";

	if($data_num > $end){
		
	}else{
		print '<script type="text/javascript"><!--
document.getElementById(\'message\').innerHTML = "<b>送信完了！</b><br><br>'.$data_num.'件の送信が完了しました。";
// --></script>';
		print "<br><a href=\"m_email_send.cgi?sid=$FORM{sid}\">戻る</a>";
		
		# 履歴データに書き込み
		my $regdata;
		my %TIME = &getdatetime();
	
		#ファイルオープン
		open(IN, "+< ./data/hist.cgi") || &error("データファイルのオープンに失敗しました。");
		flock(IN, 2);
		my @DATA;
		my @LINES_ORG = <IN>;
		foreach(@LINES_ORG){
			$_ =~ s/\r\n//g;
			$_ =~ s/\r//g;
			$_ =~ s/\n//g;
			if($_){
				my @d = split(/\t/, $_);
				if ($FORM{id} ne $d[0]) {
					$regdata .= $_."\n";
				} else {
					$regdata .= $d[0]."\t";	# ID
					$regdata .= $d[1]."\t";	# 送信開始時間
					$regdata .= "$TIME{year}$TIME{mon}$TIME{mday}$TIME{hour}$TIME{min}$TIME{sec}\t";	# 送信終了時間
					$regdata .= "$d[3]\t";	# 件名
					$regdata .= "$d[4]\t";	# 本文
					$regdata .= $d[5]."\t";	# 送信タイプ
					$regdata .= $d[6]."\t";			# HTMLメールかPLAINメール
					$regdata .= "1\t";	# バックナンバー
					$regdata .= "$d[8]\t$d[9]\t$d[10]\t$d[11]\t$d[12]\t$d[13]\t$d[14]\t$d[15]\t$d[16]\t$d[17]\t";
					if ($row_admin->{rireki_email}) {
						# 送信先
						foreach my $ref (@NEWDATA_ORG) {
							$regdata .= $ref->{email}.",";
						}
						$regdata .= "\t".($#NEWDATA_ORG + 1);
					} else {
						$regdata .= "\t".($#NEWDATA_ORG + 1);
					}
					$regdata .= "\t2\n";
				}
			}
		}
		truncate(IN, 0);
		seek(IN, 0, 0);
		print(IN $regdata);
		close(IN);
		# セッションクリア
		&clear_mailsession();
		print "<meta http-equiv=\"REFRESH\" content=\"0;URL=m_email_send_finish.cgi\">\n";
	}

	print "<br><br>\n";
	print "</div></div>\n";
	if (!$SYS->{writing}) {
		print '<div align="center">
<!-- ■■■■■■著作権について（重要！）■■■■■■ -->
<!-- 本システムは、AHREF(エーエイチレフ)に無断で下記著作権表示を削除・改変・非表示にすることは禁止しております -->
<!-- 著作権非表示に関しては、こちらをご確認下さい。 -->
<!-- http://www.ahref.org/cgityosaku.html -->
<!-- ■■■■■■■■■■■■■■■■■■■■■■■■ -->
<font size="-2" color=#999999>メルマガ配信CGI <a href="http://www.ahref.org/" title="メルマガ配信CGI ACMAILER" target="_blank">ACMAILER</a> Copyright (C) 2008 <a href="http://www.ahref.org/" target="_blank" title="エーエイチレフ">ahref.org</a> All Rights Reserved.
</font>';
	}
	print "</body>\n";
	print "</html>\n";

	exit;
}

sub sendmail_admin{
	my @NEWDATA_ORG = @_;
	
	$|=1;

	&htmlheader;
	
	print "</div>";
	
	print "<font color=\"#ff0000\"><b>送信中です・・・</b></font><br><br>";
	my $c = 1;
	my $sendername = $row_admin->{admin_name}."<$row_admin->{admin_email}>";
	foreach my $row (@NEWDATA_ORG){
		my $return = 1;
		$return = &jmailsend($row_admin->{sendmail_path},$row_admin->{admin_email},$row->{subject},$row->{body},$sendername,$sendername,"",$sendername, $FORM{mail_type});
		if ($return){
		 print "$c:"."$row_admin->{admin_email}<br>\n";
		}else{
		 print "$c:"."<font color=\"#ff0000\">送信エラー($row_admin->{admin_email})</font><br>\n";
		}
		last;
	}
	print "<br><font color=\"#ff0000\"><b>送信完了しました。</b></font><br>";
	print "<div align=\"center\">";
	print "<br><input type=\"button\" value=\"戻る\" onclick=\"history.back()\"></div>";


	&htmlfooter;
	exit;
}

sub make_graph_html() {
	my $tag = '
    <table summary="プログレスバー" border="0"
     cellpadding="0" cellspacing="1" height="2" bgcolor="black"><tr><td bgcolor="#FFFFFF">
	 <table class="frame" border="0" width="100%" height="100%">
      <tr>';
	for(1..50) {
		$tag .= '
        <td width="2" height="2" id="bar'.$_.'"
         style="background-color:#AACCFF;">
            &nbsp;
        </td>';
	}
	$tag .= '</tr>
    </table></td></tr></table><table><tr>
        <td bgcolor="white" height="5" id="percent"
         style="font-size:1.4em"></td></tr></table>
		 <SCRIPT language="JavaScript">
<!--

function setProgress(percent,barno)
{
var node = document.getElementById(\'percent\');
node.innerHTML = percent + \'パーセント\';
if(barno > 0) {
	for(i = 1; i <= barno; i++) {
	    node = document.getElementById(\'bar\'+ i);
	    node.style.backgroundColor = "#FFAACC";
	}
}
}

//-->
</SCRIPT>';
	return $tag;
}

sub clear_mailsession {
	
	$S{sender_data} = "";
	$S{mail_title} = "";
	$S{mail_body} = "";
	for(1..5) {
		$S{"search_colname".$_} = "";
		$S{"search_text".$_} = "";
	}
	&setsession($COOKIE{sid}, %S);
	return 1;
}
