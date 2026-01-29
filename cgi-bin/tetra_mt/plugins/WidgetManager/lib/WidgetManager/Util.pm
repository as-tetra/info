# WidgetManager plugin for Movable Type
# Author: Byrne Reese, Six Apart (http://www.sixapart.com)
# Released under the Artistic License
#
# $Id: Util.pm 44 2006-06-13 16:17:43Z jallen $

package WidgetManager::Util;

use strict;

sub debug {
    my $err = shift;
    my $mark = shift || '>';
    print STDERR "$mark $err\n" if $MT::Plugin::WidgetManager::DEBUG;
}

1;
