#!/usr/bin/perl -w

# Copyright 2001-2007 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: mt-wizard.cgi 1068 2007-03-23 19:05:51Z bchoate $

use strict;
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : 'lib';
use MT::Bootstrap App => 'MT::App::Wizard';
