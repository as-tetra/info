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

if(!$FORM{email}){ &error("メールアドレスのの指定が正しくありません。"); }


print "Content-type: text/html; charset=EUC-JP\n\n";
print '以下のメールを削除してもよろしいですか？
<br>
'.$FORM{email}.'
<br>
<a href="m_email_list.cgi?sid='.$FORM{sid}.'">いいえ</a>
&nbsp;&nbsp;
<a href="m_email_del_one_ctl.cgi?email='.$FORM{email}.'&sid='.$FORM{sid}.'">はい</a>
';
exit;
