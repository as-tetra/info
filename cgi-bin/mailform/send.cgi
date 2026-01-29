#!/usr/bin/perl

## 2007-04-08 Ver.5.2

#require 'jcode.pl';
use Jcode;

#server check (SPAM CHECK)
$this_server = $ENV{'SERVER_NAME'};

#CGI�\�[�X��ǉ����ǅ����������LǊ��Ǵ��ǅ�B
#ŶHTMLǉ����ǵǟǢ���������Ǆ����ǅ�B

$sendmail = '/usr/sbin/sendmail';

@mailto = ('as.tetra@gmail.com');

$thanks_url = '/';

$subject = '���u�Ǌ��ǂ���[�������(CGI�\�[�X��)';

$return_subject = 'Ǳ���x��Ǯ�Ǣ����Ǽ����ǁǐǧǾǥǢ��ǅ�B';

$return_body = <<"EOF";
Ǳ���x��Ǯ�Ǣ����Ǽ����ǁǐǧǾǥǢ��ǅ�B
���}Ǌ�S�������Ǿ��MǢǇǵ��ǅ��ǉ�A��XǮ����ǄǢ�B
--Ǿ���M���e���m�F------------------------
�������eǁ���MǄ����ǵǇ�B
[[resbody]]
------------------------------------------

EOF

$serial_file = 'count.dat';

#logfile preference
#$log_file = 'log.dat';
#$password = '0123';

($sec,$min,$hour,$day,$mon,$year) = localtime(time);$mon++;$year += 1900;
$body = sprintf("%04d-%02d-%02d %02d:%02d:%02d\n",$year,$mon,$day,$hour,$min,$sec);
$download_file_name = sprintf("%04d-%02d-%02d.csv",$year,$mon,$day,$hour,$min,$sec);
push @field, "date";
push @csv, sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year,$mon,$day,$hour,$min,$sec);

if ($ENV{'REQUEST_METHOD'} eq "POST") {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
}
else {
	$buffer = $ENV{'QUERY_STRING'};
}
@pairs = split(/&/, $buffer);
foreach $pair (@pairs) {
	($name, $value) = split(/=/, $pair);
	$name =~ tr/+/ /;
	$name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$value =~ tr/+/ /;
	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	if($name eq 'mailto'){
		@mailto = split(/\,/,$value);
	}
	elsif($name eq 'subject'){
		$subject = $value;
	}
	elsif($name eq 'thanks_url'){
		$thanks_url = $value;
	}
	elsif($name eq 'return_subject'){
		$return_subject = $value;
	}
	elsif($name eq 'return_body'){
		$return_body = $value;
	}
	elsif($name eq 'email'){
		$email = $value;
		$resbody .= "\n\/\*-${name}\n";
		$resbody .= "${value}\n";
		$body .= "\n\/\*-${name}\n";
		$body .= "${value}\n";
		push @field, "email";
		push @csv, $value;
	}
	elsif($name eq 'must_id'){
		$spam_check = $value;
	}
	elsif($name eq $null || $name eq "Submit" || $name eq "confirm_email" || $name eq "x" || $name eq "y"){
		
	}
	elsif($name eq 'sendmail'){
		$sendmail = $value;
	}
	else{
		if($name ne $prevName){
			$resbody .= "\n\/\*-${name}\n";
			$resbody .= "${value}\n";
			$body .= "\n\/\*-${name}\n";
			$body .= "${value}\n";
			$value =~ s/\r\n/\r/ig;
			$value =~ s/\r/\n/ig;
			$value =~ s/\n//ig;
			$value =~ s/\,//ig;
			
			push @field, $name;
			push @csv, $value;
		}
		else{
			$resbody .= " ${value}\n";
			$body .= " ${value}\n";
			$csv[-1] .= " ${value}";
		}
		$prevName = $name;
	}
	$form{$name} = $value;
}

if(index($spam_check,$this_server) > 0 || $this_server eq $null){
	$server_check = 1;
}
else{
	$server_check = 0;
}

if($ENV{'QUERY_STRING'} eq 'download' && $password ne $form{'password'}){
	print "Content-type: text/html\n\n";
	print "<html>\n";
	print "\t<head>\n";
	print "\t\t<title>mode::logfile download</title>\n";
	print "\t\t<style type=\"text/css\">\n";
	print "\t\t<!--\n";
	print "\t\t* {\n";
	print "\t\t\tfont-family: \"Arial\", \"Helvetica\", \"sans-serif\";font-size: 12px;\n";
	print "\t\t}\n";
	print "\t\t-->\n";
	print "\t\t</style>\n";
	print "\t</head>\n";
	print "\t<body>\n";
	print "\t\t<h1 style=\"font-size: 21px;color: #232323;\">mode::logfile download</h1>\n";
	print "\t\t<form name=\"getLogs\" action=\"\" method=\"POST\">\n";
	print "\t\t\tPASSWORD <input type=\"password\" name=\"password\" style=\"ime-mode: disabled;width: 300px;\"><input type=\"submit\" value=\"GET LOG FILE\">\n";
	print "\t\t</form>$form{'password'}</body></html>\n";
}
elsif($password eq $form{'password'} && $password ne $null && (-f $log_file)){
	chmod 0777, $log_file;
	print "Content-type: application/octet-stream; name=\"${log_file}\"\n";
	print "Content-Disposition: attachment; filename=\"${download_file_name}\"\n\n";
	open(IN,$log_file);
	print <IN>;
	chmod 0000, $log_file;
}
elsif(@mailto > 0 && $thanks_url ne $null && $spam_check eq $ENV{'HTTP_REFERER'} && ($server_check)){
	if($email eq $null){
		$email = $mailto[0];
	}
	if($subject eq $null){
		$subject = 'NO SUBJECT';
	}
	if(-f $serial_file){
		flock(FH, LOCK_EX);
			open(FH,"${serial_file}");
				$serial = <FH>;
			close(FH);
		flock(FH, LOCK_NB);
		$serial_number = sprintf("%04d",$serial);
		$subject = "(" . $serial_number . ")${subject}";
		$serial++;
		flock(FH, LOCK_EX);
			open(FH,">${serial_file}");
				print FH $serial;
			close(FH);
		flock(FH, LOCK_NB);
	}
	my($ip_address) = $ENV{'REMOTE_ADDR'};
	my(@addr) = split(/\./, $ip_address);
	my($packed_addr) = pack("C4", $addr[0], $addr[1], $addr[2], $addr[3]);
	my($name, $aliases, $addrtype, $length, @addrs);
	($name, $aliases, $addrtype, $length, @addrs) = gethostbyaddr($packed_addr, 2);
	$body .= "\n\nHOST NAME \/ " . $name . "\n";
	$body .= "IP ADDRESS \/ " . $ENV{'REMOTE_ADDR'} . "\n";
	$body .= "USER AGENT \/ " . $ENV{'HTTP_USER_AGENT'} . "\n";
	$body .= "HTTP REFERER \/ " . $ENV{'HTTP_REFERER'} . "\n";
	#&jcode'convert(*subject,'jis');
	#&jcode'convert(*body,'jis');
	Jcode::convert(\$subject,'jis');
	Jcode::convert(\$body,'jis');
	for($cnt=0;$cnt<@mailto;$cnt++){
		&sendmail($mailto[$cnt],$email,$subject,$body);
	}
	if($return_subject ne $null && $return_body ne $null && $email ne $mailto){
		$subject = $return_subject;
		$body = $return_body;
		$body =~ s/\t//g;
		#&jcode'convert(*resbody,'jis');
		#&jcode'convert(*subject,'jis');
		#&jcode'convert(*body,'jis');
		Jcode::convert(\$resbody,'jis');
		Jcode::convert(\$subject,'jis');
		Jcode::convert(\$body,'jis');
		$body =~ s/\[\[resbody\]\]/$resbody/g;
		&sendmail($email,$mailto[0],$subject,$body);
	}
	
	#log file create
	if($log_file ne $null && $password ne $null){
		if(-f $log_file){
			chmod 0777, $log_file;
			push @csv,"\r\n";
			my($put_field) = join(",",@csv);
			#&jcode'convert(*put_field,'sjis');
			Jcode::convert(\$put_field,'sjis');
			flock(FH, LOCK_EX);
				open(FH,">>$log_file");
					print FH $put_field;
				close(FH);
			flock(FH, LOCK_NB);
			chmod 0000, $log_file;
		}
		else{
			push @csv,"\r\n";
			push @field,"\r\n";
			my($put_field) = join(",",@field);
			$put_field .= join(",",@csv);
			#&jcode'convert(*put_field,'sjis');
			Jcode::convert(\$put_field,'sjis');
			flock(FH, LOCK_EX);
				open(FH,">$log_file");
					print FH $put_field;
				close(FH);
			flock(FH, LOCK_NB);
			chmod 0000, $log_file;
		}
	}
	&refresh($thanks_url);
}
elsif($spam_check ne $ENV{'HTTP_REFERER'}){
	print "Content-type: text/html\n\n";
	print "TYPE 1 ERROR\n";
}
else{
	print "Content-type: text/html\n\n";
	print "TYPE 2 ERROR\n";
}
exit;

sub refresh {
	my($refreshurl) = @_;
	print "Content-type: text/html\n\n";
	print "<html>\n";
	print "\t<head>\n";
	print "\t\t<title>sending...</title>\n";
	print "\t\t<meta http-equiv=\"Content-Type\" content=\"text/html; charset=Shift_JIS\">\n";
	print "\t\t<meta http-equiv=\"refresh\" content=\"0;URL=${refreshurl}\">\n";
	print "\t</head>\n";
	print "\t<body></body>\n";
	print "</html>\n";
}

sub sendmail {
	my($mailto,$mailfrom,$subject,$body) = @_;
	open(MAIL,"| $sendmail -f $mailfrom -t");
		print MAIL "To: $mailto\n";
		print MAIL "Errors-To: $mailto\n";
		print MAIL "From: $mailfrom\n";
		print MAIL "Subject: $subject\n";
		print MAIL "MIME-Version:1.0\n";
		print MAIL "Content-type:text/plain; charset=ISO-2022-JP\n";
		print MAIL "Content-Transfer-Encoding:7bit\n";
		print MAIL "X-Mailer:Web Mail Delivery System\n\n";
		print MAIL "$body\n";
	close(MAIL);
}
