# CustomFields - A plugin for Movable Type.
# Copyright (c) 2005-2006 Arvind Satyanarayan.

package CustomFields::Util;

use Exporter;
@CustomFields::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( find_customfield get_customfields listing );

sub find_customfield {
	my $plugin = shift;
	my ($terms) = @_;
	
	require CustomFields::CustomField;
	my $field = CustomFields::CustomField->load($terms);
	
	if(!$field){
		$terms->{blog_id} = 0;
		$field = CustomFields::CustomField->load($terms);
	}
	
	return $field;
}

sub get_customfields {
	my $plugin = shift;
	my ($terms, $system_wide) = @_;
	
	my (@fields, @term_fields);
	
	require CustomFields::CustomField;

	if($terms->{blog_id}) {
		@temp_fields = CustomFields::CustomField->load($terms);
		push @fields, @temp_fields;		
	}
	
	if($system_wide) {
		$terms->{blog_id} = 0;
		@temp_fields = CustomFields::CustomField->load($terms);
		push @fields, @temp_fields;
	}
	
	return \@fields;
}

# Shamefully copied from Wheeljack, it's too good!

sub listing {
    my $app = shift;
    my ($opt) = @_;

    my $type = $opt->{Type};
    my $tmpl = $opt->{Template} || 'list_' . $type . '.tmpl';
    my $iter_method = $opt->{Iterator} || 'load_iter';
    my $param = $opt->{Params} || {};
    my $hasher = $opt->{Code};
    my $terms = $opt->{Terms} || {};
    my $args = $opt->{Args} || {};
    my $no_html = $opt->{NoHTML};
    my $json = $app->param('json');
    $param->{json} = 1 if $json;

	use CustomFields::CustomField;
	my $class = 'CustomFields::CustomField';

    # my $class = $app->_load_driver_for($type) or return;
    my $list_pref = $app->list_pref($type);
    $param->{$_} = $list_pref->{$_} for keys %$list_pref;
    my $limit = $list_pref->{rows};
    my $offset = $app->param('offset') || 0;
    $args->{offset} = $offset if $offset;
    $args->{limit} = $limit + 1;

    # handle search parameter
    if (my $search = $app->param('search')) {
        $app->param('do_search', 1);
        my $search_param = $app->do_search_replace();
        if ($hasher) {
            my $data = $search_param->{object_loop};
            if ($data && @$data) {
                foreach my $row (@$data) {
                    my $obj = $row->{object};
                    $row = $obj->column_values();
                    $hasher->($obj, $row);
                }
            }
        }
        $param->{$_} = $search_param->{$_} for keys %$search_param;
        $param->{limit_none} = 1;
    } else {
        # handle filter options
        if ((my $filter_col = $app->param('filter'))
            && (my $val = $app->param('filter_val')))
        {
            if ((($filter_col eq 'normalizedtag') || ($filter_col eq 'exacttag'))
                && ($class->isa('MT::Taggable'))) {
                my $normalize = ($filter_col eq 'normalizedtag');
                require MT::Tag;
                require MT::ObjectTag;
                my $tag_delim = chr($app->user->entry_prefs->{tag_delim});
                my @filter_vals = MT::Tag->split($tag_delim, $val);
                my @filter_tags = @filter_vals;
                if ($normalize) {
                    push @filter_tags, MT::Tag->normalize($_) foreach @filter_vals;
                }
                my @tags = MT::Tag->load({ name => [ @filter_tags ] }, { binary => { name => 1 }});
                my @tag_ids;
                foreach (@tags) {
                    push @tag_ids, $_->id;
                    if ($normalize) {
                        my @more = MT::Tag->load({ n8d_id => $_->n8d_id ? $_->n8d_id : $_->id });
                        push @tag_ids, $_->id foreach @more;
                    }
                }
                @tag_ids = ( 0 ) unless @tags;
                $args->{'join'} = MT::ObjectTag->join_on('object_id',
                    { tag_id => \@tag_ids, object_datasource => $class->datasource }, { unique => 1 } );
            } elsif (!exists ($terms->{$filter_col})) {
                $terms->{$filter_col} = $val;
            }
            $param->{filter} = $filter_col;
            $param->{filter_val} = $val;
            my $url_val = encode_url($val);
            $param->{filter_args} = "&filter=$filter_col&filter_val=$url_val";
            $param->{"filter_col_$filter_col"} = 1;
        }

        # automagic blog scoping
        my $blog = $app->blog;
        if ($blog) {
            # In blog context, class defines blog_id as a column,
            # so restrict listing to active blog:
            if ($class->column_def('blog_id')) {
                $terms->{blog_id} ||= $blog->id;
            }
        }

        my $iter = $class->$iter_method($terms, $args)
            or return $app->error($class->errstr);
        my @data;
        while (my $obj = $iter->()) {
            my $row = $obj->column_values();
            $hasher->($obj, $row) if $hasher;
            push @data, $row;
            last if scalar @data == $limit;
        }

        $param->{object_loop} = \@data;
        $param->{object_type} = $type;

        # handle pagination
        my $pager = {
            offset => $offset,
            limit => $limit,
            rows => scalar @data,
            listTotal => $class->count($terms, $args),
            chronological => $param->{list_noncron} ? 0 : 1,
            return_args => $app->make_return_args,
        };
        require JSON;
        $param->{pager_json} = $json ? $pager : JSON::objToJson($pager);
        # pager.rows (number of rows shown)
        # pager.listTotal (total number of rows in datasource)
        # pager.offset (offset currently used)
        # pager.chronological (boolean, whether the listing is chronological or not)
    }

    my $plural = $type;
    # entry -> entries; user -> users
    if ($type =~ m/y$/) {
        $plural =~ s/y$/ies/;
    } else {
        $plural .= 's';
    }
    $param->{object_type_plural} = $app->translate($plural);
    if ($app->user->is_superuser()) {
        $param->{is_superuser} = 1;
    }

    my $plugin_actions = $app->plugin_itemset_actions($type);
    $param->{plugin_itemset_action_loop} = $plugin_actions || [];
    my $core_actions = $app->core_itemset_actions($type);
    $param->{core_itemset_action_loop} = $core_actions || [];
    $param->{has_itemset_actions} =
        (scalar(@$plugin_actions) || scalar(@$core_actions)) ? 1 : 0;

    if ($json) {
        my $html = $app->build_page($tmpl, $param);
        my $data = {
            html => $html,
            pager => $param->{pager_json},
        };
        $app->send_http_header("text/javascript+json");
        require JSON;
        $app->print(JSON::objToJson($data));
        $app->{no_print_body} = 1;
    } else {
        $no_html ? $param : $app->build_page($tmpl, $param);
    }
}

1;