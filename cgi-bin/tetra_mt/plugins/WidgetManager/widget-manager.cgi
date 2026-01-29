#!/usr/bin/perl
#
# WidgetManager plugin for Movable Type
# Author: Byrne Reese, Six Apart (http://www.sixapart.com)
# Released under the Artistic License
#
# $Id: widget-manager.cgi 42 2006-06-13 16:17:36Z jallen $

use strict;
use lib 'lib', ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : '../../lib');
use MT::Bootstrap App => 'WidgetManager::App';

__END__

