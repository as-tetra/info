#!/usr/bin/perl

use lib "./lib/";
require "./lib/setup.cgi";
require "./lib/gifcat.pl";
use strict;

our $SYS;

my $row_admin = &get_admindata();

if (!$row_admin->{counter_disp}) {
	print "Content-type: image/gif\n\n";
	binmode(STDOUT);
	print &gifcat'gifcat(("./image/no.gif"));
	exit;
}

my %FORM = &form("noexchange");
my $data_ref;
my @DATA = &openfile2array($SYS->{data_dir}."mail.cgi");

my $num = sprintf("%05d", ($#DATA + 1));

my @gif;
for (1..5) {
	my $ref = substr($num, ($_ - 1), 1);
	my $data = "./image/$ref.gif";
	push(@gif, $data);
}

print "Content-type: image/gif\n\n";
binmode(STDOUT);
print &gifcat'gifcat(@gif);
exit;
