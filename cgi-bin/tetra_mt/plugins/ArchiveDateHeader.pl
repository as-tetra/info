# Archive Date Header 1.0
# Archive Date Header plugin for Movable Type
#
# Copyright 2002 Kalsey Consulting Group
# http://kalsey.com/
# Using this software signifies your acceptance of the license
# file that accompanies this software.
#
# Installation and usage instructions can be found at
# http://kalsey.com/blog/2002/08/archive_date_header_plugin.stm

use strict;
use MT::Template::Context;

MT::Template::Context->add_container_tag(ArchiveDateHeader => \&ArchiveDateHeader);

sub ArchiveDateHeader {
    my($ctx, $args) = @_;
    my $this_date = 0;
    defined(my $at = $ctx->{current_archive_type})
        or return $ctx->error('You used an <MTArchiveDateHeader> tag ' . 
                              'outside of an archive.'); 
    my $ts = $args->{ts} || $_[0]->{current_timestamp};
    if ($at eq "Monthly") {
        $this_date = substr $ts, 0, 4;
    } elsif ($at eq "Weekly"){
        $this_date = substr $ts, 5, 6;
    } else {
        return '';
    }
    my $last_date = $ctx->{__stash}{archive_date_last_date} || 0;
    if ($this_date != $last_date) {
        $ctx->{__stash}{archive_date_last_date} = $this_date;
        my $builder = $ctx->stash('builder');
        my $tokens = $ctx->stash('tokens');
        defined(my $out = $builder->build($ctx,$tokens))
            or return '';
        return $out;
    }
}
