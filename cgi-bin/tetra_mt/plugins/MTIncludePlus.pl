# Copyright 2003 Stepan Riha. This code cannot be redistributed without
# permission from www.nonplus.net.

=head1 MTIncludePlus

Free for personal or commercial use. 

Version 1.1 - May 14, 2003
Added timeout, max_size and agent attributes to MTIncludeURL.

Version 1.0 - May 10, 2003
Initial release

=cut

## Declare modules we use
use strict;
package MT::plugins::MTIncludePlus;
use MT::Template::Context;
use vars qw( $VERSION );
my $VERSION = '1.1';

## Register MT handlers

MT::Template::Context->add_tag(IncludePlusVersion => sub { $VERSION } );
MT::Template::Context->add_container_tag(IncludeFile => \&MTIncludeFile );
MT::Template::Context->add_container_tag(IncludeModule => \&MTIncludeModule );
MT::Template::Context->add_container_tag(IncludeURL => \&MTIncludeURL );

sub MTIncludeFile {
    my($ctx, $args, $cond) = @_;
    defined (my $file = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
    	or return;
	return MT::Template::Context::_hdlr_include($ctx, { file => $file } )
}

sub MTIncludeModule {
    my($ctx, $args, $cond) = @_;
    defined (my $module = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
    	or return;
	return MT::Template::Context::_hdlr_include($ctx, { module => $module } )
}

sub MTIncludeURL {
    my($ctx, $args, $cond) = @_;
    defined (my $url = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
    	or return;
	# Create a user agent object
	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	## Specify timeout in seconds
	$ua->timeout($args->{timeout} || 15);
	## Specify max size in bytes
	$ua->max_size($args->{max_size});
	## Specify user agent
	$ua->agent(($args->{agent} || "MTIncludePlus/$VERSION") . $ua->agent);
	
	# Create a request
	my $request = HTTP::Request->new(GET => $url);
	
	# Pass request to the user agent and get a response back
	my $result = $ua->request($request);
	
	# Return blank, if error
	return '' unless $result->is_success;
	
	# Get content
	return $result->content;
}

1;
