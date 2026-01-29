# $Id $

## Declare modules we use
use strict;
package plugins::MTTagInvoke;
use MT::Template::Context;

use vars qw($VERSION);
$VERSION = "1.0";

my $plugin;
eval {
    require MT::Plugin;
    $plugin = MT::Plugin->new({
        name => 'MTTagInvoke',
        description => <<EOS
Dynamically specifying name and attributes of a MTTag.
EOS
		,
        doc_link => 'http://www.nonplus.net/software/mt/MTTagInvoke.htm',
        author_name => 'Stepan Riha',
        author_link => 'http://www.nonplus.net/software/mt/',
        version => $VERSION,
    });
    MT->add_plugin($plugin);
};

## Register MT handlers

MT::Template::Context->add_tag(TagInvokeVersion => sub { $VERSION } );
MT::Template::Context->add_container_tag('TagInvoke' => \&MTTagInvoke );
MT::Template::Context->add_container_tag('TagInvokeContent' => \&MTTagInvokeContent );
MT::Template::Context->add_container_tag('TagInvokeName' => \&MTTagInvokeName );
MT::Template::Context->add_container_tag('TagInvokeAttribute' => \&MTTagInvokeAttribute );

sub MTTagInvoke {
	require MTTagInvoke;
	MTTagInvoke::TagInvoke(@_);
}

sub MTTagInvokeContent {
	require MTTagInvoke;
	MTTagInvoke::TagContent(@_);
}

sub MTTagInvokeName {
	require MTTagInvoke;
	MTTagInvoke::TagName(@_);
}

sub MTTagInvokeAttribute {
	require MTTagInvoke;
	MTTagInvoke::TagAttribute(@_);
}

1;
