
use Test::More tests => 12;

use MT::Template::Context;
require 'multiblog.pl';

sub tag_ok {
    my ($tag) = @_;
    $tag =~ s/^MT//;
    return ok (exists $MT::Template::Context::Global_handlers{ $tag });
}

tag_ok ('MTMultiBlog');
tag_ok ('MTOtherBlog');
tag_ok ('MTMultiBlogEntries');
tag_ok ('MTMultiBlogComments');
tag_ok ('MTMultiBlogCategories');
tag_ok ('MTMultiBlogPings');
tag_ok ('MTMultiBlogEntry');
tag_ok ('MTMultiBlogComment');
tag_ok ('MTMultiBlogCategory');
tag_ok ('MTMultiBlogPing');

tag_ok ('MTMultiBlogIfLocalBlog');
tag_ok ('MTMultiBlogIfNotLocalBlog');
