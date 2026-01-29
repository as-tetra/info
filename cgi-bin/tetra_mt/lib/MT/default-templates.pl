# Copyright 2001-2007 Six Apart. This code cannot be redistributed without
# permission from www.sixapart.com.  For more details, consult 
# your Movable Type license for details.
#
# $Id: default-templates.pl 1051 2007-01-23 23:52:24Z gboggs $

package MT::default_templates;

use strict;
require MT::DefaultTemplates;

delete $INC{'MT/default-templates.pl'};

MT::DefaultTemplates->templates;
