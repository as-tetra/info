#!/usr/local/bin/perl

###############################################
#   sche28.cgi
#      V2.0 (2004.10.8)
#                     Copyright(C) CGI-design
###############################################

$script = 'sche28.cgi';
$base = './schedata';				#データ格納ディレクトリ
$opfile = "$base/option.txt";		#オプションファイル

@week = ('日','月','火','水','木','金','土');
@mdays = (31,28,31,30,31,30,31,31,30,31,30,31);

open(IN,"$opfile") || &error("OPEN ERROR");		$opdata = <IN>;		close IN;
if (!$opdata) {
	$pass = &crypt('cgi');
	chmod(0666,$opfile);	open(OUT,">$opfile") || &error("OPEN ERROR");
	print OUT "$pass<>スケジュール<><>$base/title.gif<>$base/home.gif<>$base/last.gif<>$base/next.gif<><>$base/style.css<>#fafaf5<>#333333<>#c00000<>#aaaaaa<>#eeeeee<>#ffffff<>#ff0000<>#ff0000<>#fff8ff<>#0000ff<>#f4ffff<>#fffff5<>#eeff00<>900<>12";
	close OUT;
}

##### メイン処理 #####
if ($ENV{'REQUEST_METHOD'} eq "POST") {read(STDIN, $in, $ENV{'CONTENT_LENGTH'});} else {$in = $ENV{'QUERY_STRING'};}
foreach (split(/&/,$in)) {
	($n,$val) = split(/=/);
	$val =~ tr/+/ /;
	$val =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$in{$n} = $val;
}
$dm = $in{'dm'};
$mode = $in{'mode'};

open(IN,"$opfile") || &error("OPEN ERROR");
($pass,$title,$home,$title_icon,$home_icon,$last_icon,$next_icon,$bg_img,$style_file,$bg_color,$text_color,$title_color,$frame_color,$week_color,$combg_color,$sub_color,$holi_color,$holibg_color,$sat_color,$satbg_color,$daybg_color,$today_color,$calw,$fsize) = split(/<>/,<IN>);
close IN;
@wcolor = ($holi_color,$text_color,$text_color,$text_color,$text_color,$text_color,$sat_color);

($sec,$min,$hour,$nowday,$nowmon,$nowyear) = localtime;
$nowyear += 1900;
$nowmon++;

$logyear = $in{'year'};
$logmon = $in{'mon'};
if (!$logyear) {$logyear = $nowyear; $logmon = $nowmon;}
$logfile = "$base/$logyear$logmon.txt";

$mdays = $mdays[$logmon - 1];
if ($logmon == 2 && $logyear % 4 == 0) {$mdays = 29;}

&header;
if ($mode eq 'admin') {&admin;} else {&main;}

print "</center></body></html>\n";
exit;

###
sub header {
	print "Content-type: text/html\n\n";
	print "<html><head><META HTTP-EQUIV=\"Content-type\" CONTENT=\"text/html; charset=Shift_JIS\">\n";
	print "<title>$title</title>\n";
	print "<link rel=\"stylesheet\" type=\"text/css\" href=\"$style_file\" media=\"screen,tv\">\n";
	print "<link rel=\"stylesheet\" type=\"text/css\" href=\"./schedata/print.css\" media=\"print\"></head>\n";
	$head = 1;
}

###
sub main {
	print "<body background=\"$bg_img\" bgcolor=\"$bg_color\" text=\"$text_color\" leftmargin=\"0\" topmargin=\"0\" marginwidth=\"0\" marginheight=\"0\"><center>\n";
	print "<table width=\"100%\" cellspacing=\"0\" cellpadding=\"10\" class=\"header\"><tr class=\"bar\"><td width=100 height=32 valign=top>\n";
	if ($home) {if ($home_icon) {print "<a href=\"$home\"><img src=\"$home_icon\" border=0></a>";} else {print "<a href=\"$home\">[HOME]</a>";}}
	print "</td><td align=center>";
	if ($title_icon) {print "<img src=\"$title_icon\">";} else {print "<font class=tetra>art space tetra　&quot;schedule table&quot;</font>";}
	print "</td><td width=100 valign=top align=right><a href=\"$script?mode=admin\">[管理]</a></td></tr><tr><td height=20> </td></tr></table>\n";
	&dsp;
	if (!$dm) {&dsp_cal;} else {&dsp_calt;}
	print "<div class=footer><table width=$calw><tr><td align=right><a href=\"$script?mode=admin\">[管理]</a></td></tr></table></div>\n";
	# #
	print "<a href=\"http://www.as-tetra.info\" target=\"_blank\"></a>\n";
}

###
sub dsp {
	@holi=@sub=@com=();
	$flag = 0;
	if (-e $logfile) {
		open(IN,"$logfile") || &error("OPEN ERROR");
		while (<IN>) {
			($day,$holi,$sub,$com) = split(/<>/);
			$holi[$day] = $holi;
			$sub[$day] = $sub;
			$com[$day] = $com;
		}
		close IN;
	} else {
		$flag = 1;
		&holi_set;
	}
	print "<div class=top><table width=$calw cellspacing=2 cellpadding=0><tr><td width=100><font size=\"+1\"><b>$logyear年</b></font></td><td align=right>\n";
	$mon = $logmon - 1;
	if ($mon < 1) {$mon = 12; $year = $logyear - 1;} else {$year = $logyear;}
	print "<form action=\"$script\" method=\"POST\">\n";
	print "<input type=hidden name=dm value=\"$dm\">\n";
	print "<input type=hidden name=mode value=\"$mode\">\n";
	print "<input type=hidden name=pass value=\"$inpass\">\n";
	print "<input type=hidden name=year value=\"$year\">\n";
	print "<input type=hidden name=mon value=\"$mon\">\n";
	print "<input type=image src=\"$last_icon\"></td></form>\n";
	print "<td width=100 align=center><font size=\"+2\"><b>$logmon月</b></font></td>\n";
	$mon = $logmon + 1;
	if (12 < $mon) {$mon = 1; $year = $logyear + 1;} else {$year = $logyear;}
	print "<td><form action=\"$script\" method=\"POST\">\n";
	print "<input type=hidden name=dm value=\"$dm\">\n";
	print "<input type=hidden name=mode value=\"$mode\">\n";
	print "<input type=hidden name=pass value=\"$inpass\">\n";
	print "<input type=hidden name=year value=\"$year\">\n";
	print "<input type=hidden name=mon value=\"$mon\">\n";
	print "<input type=image src=\"$next_icon\"></td></form>\n";
	if (!$dm) {$sdm = 1;} else {$sdm = 0;}
	print "<td width=100 align=right><form action=\"$script\" method=\"POST\">\n";
	print "<input type=hidden name=dm value=\"$sdm\">\n";
	print "<input type=hidden name=mode value=\"$mode\">\n";
	print "<input type=hidden name=pass value=\"$inpass\">\n";
	print "<input type=hidden name=year value=\"$logyear\">\n";
	print "<input type=hidden name=mon value=\"$logmon\">\n";
	print "<input type=submit value=\"表\示切替\"></td></form></tr></table></div>\n";
}

###
sub dsp_cal {
	print "<div class=waku><table width=$calw bgcolor=\"$combg_color\" bordercolor=\"$frame_color\" border=1 cellspacing=0 cellpadding=4 style=\"border-collapse: collapse\">\n";
	print "<tr bgcolor=\"$week_color\" align=center class=\"week\">\n";
	for (0 .. 6) {print "<td width=14%><font color=\"$wcolor[$_]\" size=\"-2\">$week[$_]</font></td>\n";}
	print "</tr>\n";

	&get_date($logyear,$logmon,1);
	$w=$n=0;
	$k=1;
	for (0 .. 41) {
		if (!$w) {print "<tr>";}
		if ($wday <= $_ && $k <= $mdays) {
			if ($w == 1) {$n++;}
			$wcolor = $wcolor[$w];
			if (!$w) {$bc = $holibg_color;} elsif ($w == 6) {$bc = $satbg_color;} else {$bc = $daybg_color;}
			if ($flag && 2002 < $logyear) {
				&get_holiday($logmon,$k,$w,$n);
				if ($holiday) {$holi[$k] = 1; $sub[$k] = $holiday;}
			}
			if ($holi[$k]) {$wcolor = $holi_color; $bc = $holibg_color;}
			if ($logyear == $nowyear && $logmon == $nowmon && $k == $nowday) {$bc = $today_color;}
			if ($k < 10) {$day = "&nbsp;$k";} else {$day = $k;}

			print "<td bgcolor=\"$bc\" height=90 valign=top><font color=\"$wcolor\" size=\"+1\"><b>$day</b></font>";
			if ($mode eq 'admin') {
				$com[$k] =~ s/<br>/\r/g;
				if ($holi[$k]) {$chk = ' checked';} else {$chk = '';}
				print "<input type=checkbox name=holi$k value=\"1\"$chk>";
				print "<input class=dt type=text name=sub$k value=\"$sub[$k]\"><br>\n";
				print "<textarea class=ds cols=15 rows=8 name=com$k wrap=soft>$com[$k]</textarea>\n";
			} else {
				print "&nbsp;<font style=\"font-size: $fsize","px\"><font color=\"$sub_color\" class=\"title\">$sub[$k]</font><br>$com[$k]</font>\n";
			}
			print "</td>\n";
			$k++;
		} else {print "<td></td>\n";}
		$w++;
		if ($w == 7) {
			print "</tr>\n";
			if ($mdays < $k) {last;}
			$w = 0;
		}
	}
	print "</table></div>\n";
}

###
sub dsp_calt {
	print "<div class=waku><table width=$calw bordercolor=\"$frame_color\" border=1 cellspacing=0 cellpadding=3 style=\"border-collapse: collapse\"><col span=1 align=right>\n";
	&get_date($logyear,$logmon,1);
	$w = $wday;
	$n = 0;
	for (1 .. $mdays) {
		$k = $_;
		if ($w == 1) {$n++;}
		$wcolor = $wcolor[$w];
		if (!$w) {$bc = $holibg_color;} elsif ($w == 6) {$bc = $satbg_color;} else {$bc = $daybg_color;}
		if ($flag && 2002 < $logyear) {
			&get_holiday($logmon,$k,$w,$n);
			if ($holiday) {$holi[$k] = 1; $sub[$k] = $holiday;}
		}
		if ($holi[$k]) {$bc = $holibg_color; $wcolor = $holi_color;}
		if ($logyear == $nowyear && $logmon == $nowmon && $k == $nowday) {$bcday = " bgcolor=\"$today_color\"";} else {$bcday = '';}

		print "<tr bgcolor=\"$bc\"><td width=60><font color=\"$wcolor\"><b>$k</b> ($week[$w])</font></td><td$bcday>\n";
		if ($mode eq 'admin') {
			if ($holi[$k]) {$chk = ' checked';} else {$chk = '';}
			print "<input type=checkbox name=holi$k value=\"1\"$chk>\n";
			print "<input type=text size=22 name=sub$k value=\"$sub[$k]\">\n";
			$com[$k] =~ s/<br>/\r/g;
			print "<textarea cols=72 rows=4 name=com$k wrap=soft>$com[$k]</textarea>";
		} else {
			if ($sub[$k]) {print "<font color=\"$sub_color\">$sub[$k]</font>　";}
			$com[$k] =~ s/([^=^\"]|^)(http\:[\w\.\~\-\/\?\&\+\=\:\@\%\;\#\%]+)/$1<a href=\"$2\" target=\"_blank\">$2<\/a>/g;
			print $com[$k];
		}
		print "</td></tr>\n";
		$w++;
		if (6 < $w) {$w = 0;}
	}
	print "</table></div>\n";
}

###
sub get_date {
	($y,$m,$d) = @_;
	if ($m < 3){$y--; $m+=12;}
	$wday = ($y+int($y/4)-int($y/100)+int($y/400)+int((13*$m+8)/5)+$d)%7;
}

###
sub holi_set {
	$def = 0.242194*($logyear-1980)-int(($logyear-1980)/4);
	$spr = int(20.8431+$def);
	$aut = int(23.2488+$def);
	%holi_d = ('0101','元日','0211','建国記念の日',"03$spr",'春分の日','0429','みどりの日','0503','憲法記念日','0505','こどもの日',"09$aut",'秋分の日','1103','文化の日','1123','勤労感謝の日','1223','天皇誕生日');
	%holi_w = ('012','成人の日','073','海の日','093','敬老の日','102','体育の日');
}

###
sub get_holiday {
	$sm = sprintf("%02d%02d",$_[0],$_[1]);
	$holiday = $holi_d{$sm};
	if ($sm eq '0504' && 1 < $_[2]) {$holiday = '国民の休日';}
	if ($holiday && !$_[2]) {$hflag = 1;}
	if (!$holiday && $_[2] == 1) {
		$smw = sprintf("%02d$_[3]",$_[0]);
		$holiday = $holi_w{$smw};
		if ($hflag) {$holiday = '振替休日'; $hflag = 0;}
	}
}

###
sub admin {
	print "<body><center>\n";
	$inpass = $in{'pass'};
	if ($inpass eq '') {
		print "<table width=97%><tr><td><a href=\"$script\">[Return]</a></td></tr></table>\n";
		print "<br><br><br><br><h4>パスワードを入力して下さい</h4>\n";
		print "<form action=\"$script\" method=\"POST\">\n";
		print "<input type=hidden name=mode value=\"admin\">\n";
		print "<input type=password name=pass size=10 maxlength=8>\n";
		print "<input type=submit value=\" 認証 \"></form>\n";
		print "</center></body></html>\n";
		exit;
	}
	$mat = &decrypt($inpass,$pass);
	if (!$mat) {&error("パスワードが違います");}

	print "<table width=100% bgcolor=\"#8c4600\"><tr><td>　<a href=\"$script\"><font color=\"#ffffff\"><b>Return</b></font></a></td>\n";
	print "<td align=right><form action=\"$script\" method=POST>\n";
	print "<input type=hidden name=mode value=\"admin\">\n";
	print "<input type=hidden name=pass value=\"$inpass\">\n";
	print "<input type=submit value=\"　編集　\">\n";
	print "<input type=submit name=set value=\"　設定　\"></td></form><td width=10></td></tr></table><br>\n";

	$wrt = $in{'wrt'};
	if ($in{'set'}) {&setup;} else {&edt;}
}

###
sub edt {
	if ($wrt) {
		open(OUT,">$logfile") || &error("OPEN ERROR");
		for (1 .. $mdays) {
			$in{"com$_"} =~ s/\r\n|\r|\n/<br>/g;
			print OUT "$_<>$in{\"holi$_\"}<>$in{\"sub$_\"}<>$in{\"com$_\"}<>\n";
		}
		close OUT;
		chmod(0666,$logfile);
	}
	&dsp;
	print "<table><tr><td><form action=\"$script\" method=\"POST\">\n";
	print "<input type=hidden name=dm value=\"$dm\">\n";
	print "<input type=hidden name=mode value=\"admin\">\n";
	print "<input type=hidden name=pass value=\"$inpass\">\n";
	print "<input type=hidden name=year value=\"$logyear\">\n";
	print "<input type=hidden name=mon value=\"$logmon\">\n";
	print "休日チェック、特記事項、スケジュールを入力後、「登録する」を押して下さい。\n";
	print "　　<input type=submit name=wrt value=\"登録する\"></td></tr></table>\n";
	if (!$dm) {&dsp_cal;} else {&dsp_calt;}
	print "</form>\n";
}

###
sub setup {
	if ($wrt) {
		if ($in{'newpass'} ne '') {$pass = &crypt($in{'newpass'});}
		$title = $in{'title'};
		$home = $in{'home'};
		$title_icon = $in{'title_icon'};
		$home_icon = $in{'home_icon'};
		$last_icon = $in{'last_icon'};
		$next_icon = $in{'next_icon'};
		$bg_img = $in{'bg_img'};
		$style_file = $in{'style'};

		$bg_color = $in{'color0'};
		$text_color = $in{'color1'};
		$title_color = $in{'color2'};
		$frame_color = $in{'color3'};
		$week_color = $in{'color4'};
		$combg_color = $in{'color5'};
		$sub_color = $in{'color6'};
		$holi_color = $in{'color7'};
		$holibg_color = $in{'color8'};
		$sat_color = $in{'color9'};
		$satbg_color = $in{'color10'};
		$daybg_color = $in{'color11'};
		$today_color = $in{'color12'};

		$calw = $in{'calw'};
		$fsize = $in{'fsize'};

		open(OUT,">$opfile") || &error("OPEN ERROR");
		print OUT "$pass<>$title<>$home<>$title_icon<>$home_icon<>$last_icon<>$next_icon<>$bg_img<>$style_file<>$bg_color<>$text_color<>$title_color<>$frame_color<>$week_color<>$combg_color<>$sub_color<>$holi_color<>$holibg_color<>$sat_color<>$satbg_color<>$daybg_color<>$today_color<>$calw<>$fsize";
		close OUT;
	}

	print "<form action=\"$script\" method=\"POST\">\n";
	print "<input type=hidden name=mode value=\"admin\">\n";
	print "<input type=hidden name=pass value=\"$inpass\">\n";
	print "<input type=hidden name=set value=\"1\">\n";
	print "<input type=submit name=wrt value=\"設定する\"><br><br>\n";

	print "<table bgcolor=\"#dddddd\" cellspacing=10><tr><td><table cellspacing=1 cellpadding=0>\n";
	print "<tr><td><b>タイトル</b></td><td><input type=text name=title size=40 value=\"$title\"></td></tr>\n";
	print "<tr><td><b>ホームURL</b></td><td><input type=text size=60 name=home value=\"$home\"></td></tr>\n";
	print "<tr><td><b>タイトルアイコン</b></td><td><input type=text size=60 name=title_icon value=\"$title_icon\">";
	if ($title_icon) {print "　<img src=\"$title_icon\">";}
	print "</td></tr>\n";
	print "<tr><td><b>ホームアイコン</b></td><td><input type=text size=60 name=home_icon value=\"$home_icon\">";
	if ($home_icon) {print "　<img src=\"$home_icon\">";}
	print "</td></tr>\n";
	print "<tr><td><b>LASTアイコン</b></td><td><input type=text size=60 name=last_icon value=\"$last_icon\">　<img src=\"$last_icon\"></td></tr>\n";
	print "<tr><td><b>NEXTアイコン</b></td><td><input type=text size=60 name=next_icon value=\"$next_icon\">　<img src=\"$next_icon\"></td></tr>\n";
	print "<tr><td><b>壁紙</b></td><td><input type=text size=60 name=bg_img value=\"$bg_img\">";
	if ($bg_img) {print "　<img src=\"$bg_img\" width=30>";}
	print "</td></tr>\n";
	print "<tr><td><b>スタイルシート</b></td><td><input type=text size=60 name=style value=\"$style_file\"></td></tr>\n";

	print "<tr><td></td><td><a href=\"$base/color.htm\" target=\"_blank\">カラーコード</a></td></tr>\n";
	@name = ('基本背景色','基本文字色','タイトル','枠色','曜日背景色','カレンダー背景色','特記事項','休日の日付','休日の背景色','土曜日の日付','土曜日の背景色','平日の背景色','本日の背景色');
	@data = ($bg_color,$text_color,$title_color,$frame_color,$week_color,$combg_color,$sub_color,$holi_color,$holibg_color,$sat_color,$satbg_color,$daybg_color,$today_color);
	for (0 .. $#name) {
		print "<tr><td><b>$name[$_]</b></td><td><table cellspacing=0 cellpadding=0><tr>\n";
		print "<td><input type=text name=color$_ size=10 value=\"$data[$_]\"></td>\n";
		print "<td width=5></td><td width=80 bgcolor=\"$data[$_]\"></td></tr></table></td></tr>\n";
	}
	print "<tr><td><b>表\示サイズ</b></td><td>カレンダー横幅<input type=text size=4 name=calw value=\"$calw\" style=\"text-align: right\">px\n";
	print "　　文字サイズ<input type=text size=3 name=fsize value=\"$fsize\" style=\"text-align: right\">px</td></tr>\n";
	print "<tr><td><b>パスワード変更</b></td><td><input type=password name=newpass size=10 maxlength=8> （英数8文字以内）</td></tr>\n";
	print "</table></td></tr></table></form>\n";
}

###
sub crypt {
	@salt = ('a' .. 'z','A' .. 'Z','0' .. '9');
	srand;
	$salt = "$salt[int(rand($#salt))]$salt[int(rand($#salt))]";
	return crypt($_[0],$salt);
}

###
sub decrypt {
	$salt = $_[1] =~ /^\$1\$(.*)\$/ && $1 || substr($_[1],0,2);
	if (crypt($_[0],$salt) eq $_[1] || crypt($_[0],'$1$' . $salt) eq $_[1]) {return 1;}
	return 0;
}

###
sub error {
	if (!$head) {&header; print "<body><center>\n";}
	print "<br><br><br><br><h3>ERROR !!</h3><font color=red><b>$_[0]</b></font>\n";
	print "</center></body></html>\n";
	exit;
}
