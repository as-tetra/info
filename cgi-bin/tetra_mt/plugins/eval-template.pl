#
# Copyright 2005 Yuki Fujimura <fujimura@wakhok.ac.jp>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package MT::Plugin::EvalTemplate;

use strict;
use warnings;

use MT;
use MT::Plugin;
use MT::Template::Context;


our $VERSION = 2.2;


MT->add_plugin(
    MT::Plugin->new(
        'name' => 'EvalTemplate',
        'version' => $VERSION,
        'author_name' => 'Yuki Fujimura',
        'author_link' => 'http://www.wakhok.ac.jp/~fujimura/',
        'doc_link' => 'http://www.wakhok.ac.jp/~fujimura/2005/08/14/010500',
    )
);


MT::Template::Context->add_global_filter('eval' => sub {
    my ($text, $argument, $context) = @_;

    if ($argument) {
        my $builder = $context->stash('builder');
        my $tokens = $builder->compile($context, $text) or die($builder->errstr);

        defined($text = $builder->build($context, $tokens)) or die($builder->errstr);
    }

    return $text;
});


{
    my $original = \&MT::Template::Context::_hdlr_entry_excerpt;

    MT::Template::Context->add_tag('EntryExcerpt' => sub {
        use MT::Util;

        my ($context, $args) = @_;
        return $original->(@_) unless $args->{'eval'};
        return '' if $args->{'no_generate'};

        my $entry = $context->stash('entry');
        my $builder = $context->stash('builder');

        my $tokens = $builder->compile($context, $entry->text);
        my $excerpt = $builder->build($context, $tokens);

        if ($args->{'convert_breaks'}) {
            my $filters = $entry->text_filters;
            push @$filters, '__default__' unless @$filters;
            $excerpt = MT->apply_text_filters($excerpt, $filters, $context);
        }

        my $blog = $entry->blog()
            or return $entry->error(MT->translate('Load of blog failed: [_1]', MT::Blog->errstr));

        my $words_in_excerpt = $blog->words_in_excerpt || 40;

        eval('use MT::I18N');

        if ($@) {
            $excerpt = MT::Util::first_n_words($excerpt, $words_in_excerpt);
        } else {
            $excerpt = MT::I18N::first_n($excerpt, $words_in_excerpt);
        }

        return $excerpt . '...';
    });
}


{
    use MT::App::Search;

    my $original = \&MT::App::Search::_search_hit;

    my $replacement = sub
    {
        my ($app, $entry) = @_;

        my @text_elements = ();
        if ($app->{searchparam}{SearchElement} ne 'comments') {
            use MT::Builder;
            use MT::Template::Context;

            my $context = MT::Template::Context->new();
            $context->stash('entry', $entry);
            $context->stash('blog', $entry->blog);
            my $builder = MT::Builder->new();

            push(@text_elements, $entry->title, $entry->keywords);
            foreach my $text ($entry->text, $entry->text_more) {
                my $tokens = $builder->compile($context, $text);
                push(@text_elements, $builder->build($context, $tokens) || '');
            }
        }
        if ($app->{searchparam}{SearchElement} ne 'entries') {
            my $comments = $entry->comments;
            for my $comment (@$comments) {
                push @text_elements, $comment->text, $comment->author,
                $comment->url;
            }
        }
        return 1 if $app->is_a_match(join("\n", map $_ || '', @text_elements));
    };

    no strict 'refs';
    no warnings 'redefine';

    *MT::App::Search::_search_hit = $replacement;
}


1;
