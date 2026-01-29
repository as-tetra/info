# CustomFields - A plugin for Movable Type.
# Copyright (c) 2005-2006, Arvind Satyanarayan.

package CustomFields::App;
use strict;
use MT::Util qw( dirify encode_html );
use CustomFields::Util qw( find_customfield get_customfields listing );
use File::Basename;

# The actual CustomFields Application

sub list_customfields {
	my ($plugin, $app) = @_;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id') || 0;
	my $datasource = $q->param('datasource') || 'author';
	
	local $app->{state_params} = [ @{ $app->{state_params} }, 'datasource' ];
	
	my $hasher = sub {
		my ($obj, $row) = @_;
		my $type = $obj->type;
		
		my %types = (
			'text' => "Single-Line Text",
	   		'textarea' => "Multi-Line Textfield",
	   		'checkbox' => 'Checkbox',
	   		'url' => 'URL',
	   		'date' => 'Date',
	   		'select' => 'Drop Down Menu',
			'radio' => 'Radio Buttons',
			'file_upload' => 'File Upload', 
			'image_upload' => 'Image Upload'
		);
		
		$row->{"$type"} = 1;	
		$row->{type} = $plugin->translate($types{$type})
		
	};
	if($datasource eq 'entry') {
		$app->add_breadcrumb($plugin->translate("Custom Entry Fields"));
	} elsif($datasource eq 'author') {
		$app->add_breadcrumb($plugin->translate("Custom Author Fields"));
	} elsif($datasource eq 'category') {
		$app->add_breadcrumb($plugin->translate("Custom Category Fields"));
	}
    return listing($app, {
        Terms => { blog_id => ($datasource ne 'author' ? $blog_id : 0), field_datasource => $datasource },
        Args => { sort => 'name', 'direction' => 'ascend' },
        Type => 'customfield',
		Code => $hasher,
		Template => $plugin->load_tmpl('list_customfield.tmpl'),
        Params => {
	        ($blog_id ? (
                blog_id => $blog_id,
                edit_blog_id => $blog_id,
            ) : ()),
			"is_$datasource" => 1,
			datasource => $datasource,
			list_noncron => 1,
			saved_deleted => $q->param('saved_deleted') || 0,
			saved => $q->param('saved') || 0
        },
    });
}

sub edit_customfields {
    my ($plugin, $app) = @_;

	local $app->{state_params} = [ @{ $app->{state_params} }, 'datasource' ];
	
	my $blog_id = $app->param('blog_id');
	my $id = $app->param('id');
	my $datasource = $app->param('datasource');
	my $param;
	if ($id) {
		require CustomFields::CustomField;
		my $field = CustomFields::CustomField->load($id);
		$datasource ||= $field->field_datasource;
		$param = $field->column_values();
		my $type = $field->type;
		$param->{"$type"} = 1;
		if($type eq 'image_upload') {
			foreach (split /,/, $field->options) {
				if($_ =~ m/(.*)=(.*)/) {
					$param->{"thumb_$1"} = $2;
					$param->{"thumb_$1_$2"} = 1;
				}
			}
		}
		
	}
	eval { require MT::Image; MT::Image->new or die; };
    $param->{do_thumb} = !$@ ? 1 : 0;
	$param->{datasource} = $datasource;
	$param->{"is_$datasource"} = 1;
	$param->{saved} = $app->param('saved') || 0;
	# $param->{return_args} = $app->param('return_args');
	my $breadcrumb = $app->uri('mode' => 'list_customfields', args => { blog_id => $blog_id, datasource => $datasource });
	if($datasource eq 'entry') {
		$app->add_breadcrumb($plugin->translate("Custom Entry Fields"), $breadcrumb);
	} elsif($datasource eq 'author') {
		$app->add_breadcrumb($plugin->translate("Custom Author Fields"), $breadcrumb);
	} elsif($datasource eq 'category') {
		$app->add_breadcrumb($plugin->translate("Custom Category Fields"), $breadcrumb);
	}
	$app->add_breadcrumb($plugin->translate('Edit CustomField'));
    $app->build_page($plugin->load_tmpl('edit_customfield.tmpl'), $param);
}

sub save_customfields {
    my ($plugin, $app) = @_;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	
	local $app->{state_params} = [ @{ $app->{state_params} }, 'datasource' ];
	
	if($q->param('_type') eq 'entry_field_order') {
		require MT::PluginData;
		my $field_order = MT::PluginData->get_by_key({ plugin => 'CustomFields', key => 'author_'.$app->user->id });
		my $data = $field_order->data;
		$data->{$blog_id} = $q->param('order');
		$field_order->data($data);
		$field_order->save or die $field_order->errstr;
		$app->add_return_arg(saved_prefs => 1);
	} elsif($q->param('_type') eq 'customfield') {
		return $app->error($plugin->translate('Please ensure all required fields have been filled in.')) 
			if !$q->param('name') || !$q->param('tag') || !$q->param('type');
			
		require CustomFields::CustomField;
		my $class = 'CustomFields::CustomField';
		
		my($obj);
	    if (my $id = $q->param('id')) {
	        $obj = $class->load($id);
	    } else {
	        $obj = $class->new;
	    }
	    my $original = $obj->clone();
	    my $names = $obj->column_names;
	
		if($q->param('type') eq 'image_upload') {
			my @options;
			foreach (qw(width width_type height height_type)) {
				push @options, (join '=', $_, $q->param("thumb_$_"));
			}
			$q->param('options', join ',', @options);
		}
		
	    my %values = map { $_ => (scalar $q->param($_)) } @$names;
		$values{required} = 0 
	        if !defined($values{required}) ||
	           $q->param('required') eq '';
	
		$obj->set_values(\%values);
		$obj->save or
	        return $app->error($app->translate(
	            "Saving object failed: [_1]", $obj->errstr));
	
		$app->add_return_arg('id' => $obj->id);
		$app->add_return_arg('saved' => 1);
	
	}
    $app->call_return;
}

sub delete_customfields {
	my ($plugin, $app) = @_;
	
	require CustomFields::CustomField;
	for my $id ($app->param('id')) {
        next unless $id; # avoid 'empty' ids

		my $obj = CustomFields::CustomField->load($id);
		next unless $obj;
		
		$obj->remove or return $app->error($obj->errstr);
	}
	
	$app->add_return_arg(saved_deleted => 1);
	$app->call_return;
}

# Hooks to integrate CustomFields into MT

sub pre_save{
	my ($plugin, $cb, $obj, $original) = @_;
	my $app = MT->instance;
	
	return if !($app->can('param')); # God knows where we'll be coming from!
	
	return if !($app->param('customfield_beacon'));
	
	my @fields = $app->param;
	foreach (@fields) {
        if (m/(.*)_required$/ && $app->param($_) && !$app->param($1)) {
			$app->send_http_header;
			$app->print($app->show_error($plugin->translate('Please ensure all required fields have been filled in.')));
			$app->{no_print_body} = 1;
			exit();
        }		
	}
}

sub post_save {
	my ($plugin, $cb, $obj, $original) = @_;
	my $app = MT->instance;
	my $q = $app->{query};
	
	return if !($app->can('param')); # God knows where we'll be coming from!

	return if !($q->param('customfield_beacon'));
	my $blog_id = $q->param('blog_id');
	my $id = $obj->id;
	my $datasource = $obj->datasource;

	my (@fields, @temp_fields, $data);	

 	@temp_fields = $q->param();
    foreach (@temp_fields) {
        if (m/^customfield_(.*?)$/) {
            $data->{$1} = $q->param("customfield_$1");
        }
    }
	require MT::PluginData;
	my $obj_data = MT::PluginData->get_by_key({ plugin => 'CustomFields', key => "${datasource}_${id}"});	
	$obj_data->data($data);
	$obj_data->save or die $obj_data->errstr;
	
	if($app->user) {
		require MT::PluginData;
		my $author_data = MT::PluginData->get_by_key({ plugin => 'CustomFields', key => 'author_'.$app->user->id });
		my $data = $author_data->data;
	    foreach (@temp_fields) {
	        if (m/^customfield_(.*?)_height$/) {
	            $data->{"${1}_height"} = $q->param("customfield_${1}_height");
	        }
	    }	
		$author_data->data($data);
		$author_data->save or die $author_data->errstr;		
	}
	
	if($datasource eq 'entry') {
		&rebuild_author_archives($app, $obj);
	}
}

sub _field_loop_param {
	my($plugin, $cb, $app, $param, $tmpl) = @_;
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	my $datasource = $q->param('_type');
	my $id = $q->param('id') || ($datasource eq 'author' ? $q->param('author_id') : '');
	my $perms = $app->{perms};
	my (@fields, @field_loop);
	
	@fields = @{ get_customfields($plugin, { field_datasource => $datasource, blog_id => $blog_id}, 1) };
	
	require MT::PluginData;
	my $data = MT::PluginData->load({ plugin => 'CustomFields', key => "${datasource}_${id}"});
	my $author_data = MT::PluginData->load({ plugin => 'CustomFields', key => 'author_'.$app->user->id });
	foreach my $field (@fields) {
		my $row = $field->column_values();
		my $id = $field->id;
		my $type = $field->type;
		my @option_loop;
		$row->{value} = $data ? $data->data->{$id} : $field->default;
		if($type eq 'url' || $type eq 'date') {
			$row->{type} = 'text';
			$row->{is_text} = 1;
		} elsif($type eq 'select' || $type eq 'radio') {
  			my @options = split /\s*,\s+/, $field->options;
  			foreach my $option (@options) {
  				my $option_row = { option => $option };
				$option_row->{is_selected} = ($row->{value} eq $option);			
  				push @option_loop, $option_row;
  			}
  		} elsif($type eq 'textarea') {
			$row->{disp_prefs_height_extended} = $author_data ? $author_data->data->{"${id}_height"} : '';
		} elsif($type =~ m/upload/) {
			$row->{is_upload} = 1;
		}
		$row->{show_field} = $param->{"disp_prefs_show_customfield_$id"} || ($datasource eq 'entry' && $perms->entry_prefs =~ m/Advanced/) || ($datasource ne 'entry');
		$row->{option_loop} = \@option_loop;
		$row->{"is_$type"} = 1;
		push @field_loop, $row; 
	}
	$param->{field_loop} = \@field_loop;
}

sub _add_defaults {
	my ($plugin, $app, $tmpl) = @_; 
	
	my $old = qq{<TMPL_INCLUDE NAME="header.tmpl">};
	$old = quotemeta($old);
	
	my $new = <<HTML;
	<script type="text/javascript" src="<TMPL_VAR NAME=STATIC_URI>plugins/CustomFields/js/date-picker.js"></script>
	<link rel="stylesheet" href="<TMPL_VAR NAME=STATIC_URI>plugins/CustomFields/styles.css" type="text/css" />
	<script type="text/javascript" src="<TMPL_VAR NAME=STATIC_URI>plugins/CustomFields/js/dbx.js"></script>
	<script type="text/javascript" src="<TMPL_VAR NAME=STATIC_URI>plugins/CustomFields/js/customfields.js"></script>
	<div style="opacity:0.9; border: 1px solid #999; padding: 0px 5px; background: #FFFFCC; padding: 0px 5px; position:absolute; width:100px; display:none;" id="customfield-description">

	</div>
HTML
	$$tmpl =~ s/($old)/$1\n$new\n/;
	
}

sub _edit_entry {
	my ($plugin, $cb, $app, $tmpl) = @_;
	my (%fields_html, $old, $new);
	my $blog_id = $app->param('blog_id');
	
	_add_defaults($plugin, $app, $tmpl);
	
	## First we place field markers to slurp them up later. 
	
	$old = q{<div id="body-box">};
	$old = quotemeta($old);
	$new = qq{<!-- start-body-box -->\n<!-- start-drop-fields -->\n\n<!-- end-drop-fields -->\n<!-- start-body -->};
	$$tmpl =~ s/($old)/$1\n$new\n/;
	
	$old = <<HTML;
<TMPL_IF NAME=DISP_PREFS_SHOW_EXTENDED>
<div class="field">
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<!-- end-body -->
<TMPL_IF NAME=DISP_PREFS_SHOW_EXTENDED>
<!-- start-more -->
<div class="field">
HTML
	$$tmpl =~ s/$old/$new/;
	
	$old = <<HTML;
</TMPL_IF>

<TMPL_IF NAME=DISP_PREFS_SHOW_EXCERPT>
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<!-- end-more -->	
</TMPL_IF>

<TMPL_IF NAME=DISP_PREFS_SHOW_EXCERPT>
<!-- start-excerpt -->
HTML
	
	$$tmpl =~ s/$old/$new/;
	
	$old = <<HTML;
</TMPL_IF>

<TMPL_IF NAME=DISP_PREFS_SHOW_KEYWORDS>
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<!-- end-excerpt -->	
</TMPL_IF>

<TMPL_IF NAME=DISP_PREFS_SHOW_KEYWORDS>
<!-- start-keywords -->
HTML

	$$tmpl =~ s/$old/$new/;	
	
	$old = <<HTML;
</TMPL_IF>



<TMPL_IF NAME=DISP_PREFS_SHOW_TAGS>
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<!-- end-keywords -->	
</TMPL_IF>



<TMPL_IF NAME=DISP_PREFS_SHOW_TAGS>
<!-- start-tags -->
HTML
	$$tmpl =~ s/$old/$new/;	
	
	my $field_loop_tmpl = File::Spec->catdir($plugin->{full_path},'tmpl','field_loop.tmpl');
	$old = <<HTML;
<!--[if lte IE 6.5]></div><![endif]-->
</div>
</TMPL_IF>
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<!--[if lte IE 6.5]></div><![endif]-->
</div>
<!-- end-tags -->
</TMPL_IF>
<TMPL_INCLUDE NAME="$field_loop_tmpl">
<!-- end-body-box -->
HTML
	$$tmpl =~ s/$old/$new/;
	
	my $reorder_panel_tmpl = File::Spec->catdir($plugin->{full_path},'tmpl','reorder_panel.tmpl');
	$old = q{<div class="side-link">};
	$old = quotemeta($old);
	$new = qq{<TMPL_INCLUDE NAME="$reorder_panel_tmpl">};
	$$tmpl =~ s/($old)/$new\n$1\n/;	
}

sub _edit_entry_reorder {
	my ($plugin, $cb, $app, $tmpl_str, $param, $tmpl) = @_;
	my $blog_id = $app->param('blog_id');
	my ($old, $new);
	
	## Using our previous markers, change the order
	require MT::PluginData;
	my $field_order = MT::PluginData->load({ plugin => 'CustomFields', key => 'author_'.$app->user->id });
	
	
	my @order = $field_order ? split '::', $field_order->data->{$blog_id} : [];
	my ($drop_fields, $drop_panels); 

	foreach my $field (@order) {
		# First re-order #body-box
		if($$tmpl_str =~ m/<!-- start-$field -->(.*?)<!-- end-$field -->/s) {
			$drop_fields = join "\n", $drop_fields, $1;
			$old = quotemeta($1);
			$$tmpl_str =~ s/$old//;		
		}
		
		# Then re-order the panels 
		if($$tmpl_str =~ m/<!-- start-handle-$field -->(.*?)<!-- end-handle-$field -->/s) {
			$drop_panels = join "\n", $drop_panels, $1;
			$old = quotemeta($1);
			$$tmpl_str =~ s/$old//;		
		}		
		
	}
	
	$old = qq{<!-- start-drop-fields -->\n\n<!-- end-drop-fields -->};
	$old = quotemeta($old);
	$$tmpl_str =~ s/$old/$drop_fields/;
	
	$old = qq{<!-- start-drop-panels -->\n\n<!-- end-drop-panels -->};
	$old = quotemeta($old);
	$$tmpl_str =~ s/$old/$drop_panels/;
	
}

sub _entry_prefs {
	my ($plugin, $cb, $app, $tmpl) = @_;
	my $blog_id = $app->param('blog_id');
	
	my @fields = @{ get_customfields($plugin, { field_datasource => 'entry', blog_id => $blog_id}, 1) };
	my $i = 0;
	foreach my $field (@fields) {
		my ($old, $new);
		my $id = $field->id;
		my $name = $field->name;
		$old = qq{var customizable_fields = new Array('category'};	
		$old = quotemeta($old);	
		$new = qq{var customizable_fields = new Array('category','customfield_${id}'};
		$$tmpl =~ s/$old/$new/;
		
		$old = qq{<TMPL_IF NAME=DISP_PREFS_SHOW_PING_URLS>custom_fields.push('ping-urls');</TMPL_IF>};
		$old = quotemeta($old);
		$new = qq{<TMPL_IF NAME=DISP_PREFS_SHOW_CUSTOMFIELD_${id}>custom_fields.push('customfield_${id}');</TMPL_IF>};
		$$tmpl =~ s/($old)/$1\n$new\n/;
		
		if($i < ((scalar @fields)/2)) {
			$old = qq{<li><label><input type="checkbox" name="custom_prefs" id="custom-prefs-keywords" value="keywords" onclick="setCustomFields(); return true"<TMPL_IF NAME=DISP_PREFS_SHOW_KEYWORDS> checked="checked"</TMPL_IF><TMPL_UNLESS NAME=DISP_PREFS_CUSTOM> disabled="disabled"</TMPL_UNLESS> class="cb" /> <MT_TRANS phrase="Keywords"></label></li>};
		} else {
			$old = qq{<li><label><input type="checkbox" name="custom_prefs" id="custom-prefs-ping-urls" value="ping_urls" onclick="setCustomFields(); return true"<TMPL_IF NAME=DISP_PREFS_SHOW_PING_URLS> checked="checked"</TMPL_IF><TMPL_UNLESS NAME=DISP_PREFS_CUSTOM> disabled="disabled"</TMPL_UNLESS> class="cb" /> <MT_TRANS phrase="Outbound TrackBack URLs"></label></li>};
		}
		$old = quotemeta($old);
		$new = qq{<li><label><input type="checkbox" name="custom_prefs" id="custom-prefs-customfield_${id}" value="customfield_${id}" onclick="setCustomFields(); return true"<TMPL_IF NAME=DISP_PREFS_SHOW_CUSTOMFIELD_${id}> checked="checked"</TMPL_IF><TMPL_UNLESS NAME=DISP_PREFS_CUSTOM> disabled="disabled"</TMPL_UNLESS> class="cb" /> ${name}</label></li>};
		$$tmpl =~ s/($old)/$1\n$new\n/;
		
		$i++;
	}
	
}

sub _edit_category {
	my ($plugin, $cb, $app, $tmpl) = @_;
	my (%fields_html, $old, $new);
	my $blog_id = $app->param('blog_id');
	
	_add_defaults($plugin, $app, $tmpl);
	
	my $field_loop_tmpl = File::Spec->catdir($plugin->{full_path},'tmpl','field_loop.tmpl');
	$old = <<HTML;
<p><label for="description"><MT_TRANS phrase="Description"></label> <a href="#" onclick="return openManual('categories', 'category_description')" class="help">?</a><br />
<textarea name="description" id="description" rows="5" cols="72" class="wide"><TMPL_VAR NAME=DESCRIPTION ESCAPE=HTML></textarea></p>
HTML
	$old = quotemeta($old);
	$new = qq{<TMPL_INCLUDE NAME="$field_loop_tmpl">};
	$$tmpl =~ s/($old)/$1\n$new\n/;
			
}

sub _edit_author {
	my ($plugin, $cb, $app, $tmpl) = @_;
	my (%fields_html, $old, $new);
	my $blog_id = $app->param('blog_id');
	
	_add_defaults($plugin, $app, $tmpl);
	
	my $field_loop_tmpl = File::Spec->catdir($plugin->{full_path},'tmpl','field_loop.tmpl');
	
	$old = qq{<div style="text-align: center};
	$old = quotemeta($old);
	$new = <<HTML;
<TMPL_IF NAME=FIELD_LOOP>
<div id="edit-author">

<h3 class="customfields_header"><MT_TRANS phrase="Profile"></h3>	
<TMPL_INCLUDE NAME="$field_loop_tmpl">

</div>
</TMPL_IF>	
HTML
	$$tmpl =~ s/($old)/$new\n$1\n/;
}

sub _upload_field_id {
	my ($plugin, $cb, $app, $tmpl) = @_;
	my $field_id = $app->param('field_id');
	
	my $old = qq{<input type="hidden" name="blog_id" value="<TMPL_VAR NAME=BLOG_ID>" />};
	$old = quotemeta($old);
	my $new = qq{<input type="hidden" name="field_id" value="$field_id" />};
	
	$$tmpl =~ s/($old)/$1\n$new/;
}

sub _upload_complete_param {
	my ($plugin, $cb, $app, $param, $tmpl) = @_;
	
	return unless $app->param('field_id');
	
	my $blog_id = $app->param('blog_id');
	my $field_id = $app->param('field_id');
	
	my $field = find_customfield($plugin, { id => $field_id, blog_id => $blog_id });
	
	return unless $field->type =~ m/upload/;
	
	if($field->type eq 'image_upload') {
		foreach (split /,/, $field->options) {
			if($_ =~ m/(.*)=(.*)/) {
				$param->{"thumb_$1"} = $2;
				$param->{"thumb_$1_$2"} = 1;
			}
		}
	}
	$param->{field_id} = $field_id; 
	$param->{not_constrained} = 1 if($param->{thumb_width} && $param->{thumb_height});
	$param->{create_thumbnail} = 1 if($param->{thumb_width} != '' || $param->{thumb_height} != '');
	$param->{can_post} = 0; # A little hack makes life much easier!
}

sub _upload_complete {
	my ($plugin, $cb, $app, $tmpl) = @_;
	
	return unless $app->param('field_id');
	
	my ($old, $new);
	
	$old = qq{<blockquote>};
	$old = quotemeta($old);
	$new = qq{<blockquote style="display:none;"};
	
	# $$tmpl =~ s/$old/$new/;
	
	$old = qq{var url = '<TMPL_VAR NAME=SCRIPT_URL>?__mode=show_upload_html};
	$old = quotemeta($old);
	$new = qq{&field_id=<TMPL_VAR NAME=FIELD_ID>};
	$$tmpl =~ s/($old)/$1$new/;
	
	$old = <<HTML;
<p><MT_TRANS phrase="Would you like this file to be a:"></p>

<div>
<TMPL_IF NAME=IS_IMAGE>
<input type="button" onclick="doClick(this.form, 'popup=1&amp;width=<TMPL_VAR NAME=WIDTH>&amp;height=<TMPL_VAR NAME=HEIGHT>&amp;image_type=<TMPL_VAR NAME=IMAGE_TYPE>')" value="<MT_TRANS phrase="Popup Image">" />
<input type="button" onclick="doClick(this.form, 'include=1&width=<TMPL_VAR NAME=WIDTH>&height=<TMPL_VAR NAME=HEIGHT>&image_type=<TMPL_VAR NAME=IMAGE_TYPE>')" value="<MT_TRANS phrase="Embedded Image">" />
<TMPL_ELSE>
<input type="button" onclick="doClick(this.form, 'link=1')" value="<MT_TRANS phrase="Link">" />
</TMPL_IF>
</div>
HTML
	$old = quotemeta($old);
	$new = <<HTML;
<div>
<input type="button" onclick="doClick(this.form, '<TMPL_IF NAME=IS_IMAGE>include=1&width=<TMPL_VAR NAME=WIDTH>&height=<TMPL_VAR NAME=HEIGHT>&image_type=<TMPL_VAR NAME=IMAGE_TYPE><TMPL_ELSE>link=1</TMPL_IF>')" value="<MT_TRANS phrase="Continue">" />
</div>
HTML

	$$tmpl =~ s/$old/$new/;

	
	# Next insert our javascript
	$old = qq{</form>};
	$old = quotemeta($old);
	$new = <<HTML;
<TMPL_IF NAME=DO_THUMB>	
<script type="text/javascript">
<!--
	window.onload = function(event) {
		var f = document.getElementsByTagName('form')[0];
		
		<TMPL_UNLESS NAME=CREATE_THUMBNAIL>return;</TMPL_UNLESS>
		
		f.thumb.checked = true;
		
		<TMPL_IF NAME=NOT_CONSTRAINED>f.constrain.checked = false;</TMPL_IF>
		
		f.thumb_height.value = '<TMPL_VAR NAME=THUMB_HEIGHT>';
		f.thumb_height_type.value = '<TMPL_VAR NAME=THUMB_HEIGHT_TYPE>';
		f.thumb_width.value = '<TMPL_VAR NAME=THUMB_WIDTH>';
		f.thumb_width_type.value = '<TMPL_VAR NAME=THUMB_WIDTH_TYPE>';
		
		<TMPL_UNLESS NAME=NOT_CONSTRAINED>adjustWidthHeight(f, <TMPL_IF NAME=THUMB_HEIGHT>0<TMPL_ELSE>1</TMPL_IF>);</TMPL_UNLESS>
	}
//-->
</script>
</TMPL_IF>
HTML
	$$tmpl =~ s/($old)/$1\n$new/;
	
}

sub _show_upload_html_param {
	my ($plugin, $cb, $app, $param, $tmpl) = @_;
	my ($url, $match);
	
	return unless $app->param('field_id');
	
	my $text = $param->{upload_html};
	
	if($text =~ m!src="(.*?)"!) {
		$url = $1;
	} 
	
	if(!$url) {
		if($text =~ m!href="(.*?)"!) {
			$url = $1;
		}		
	}
	
	$param->{url} = $url;
	$param->{field_id} = $app->param('field_id');
}

sub _show_upload_html {
	my ($plugin, $cb, $app, $tmpl) = @_;
	
	return unless $app->param('field_id');
	
	my $old = qq{</form>};
	$old = quotemeta($old);
	my $new = <<HTML;
<script type="text/javascript">
<!--
	window.onload = function(event) {
		window.opener.fill_upload_field('<TMPL_VAR NAME=FIELD_ID>', '<TMPL_VAR NAME=URL ESCAPE=JS>', '<TMPL_VAR NAME=UPLOAD_HTML ESCAPE=JS>');
		window.close();
	}
//-->
</script>
HTML
	$$tmpl =~ s/($old)/$1\n$new/;	
	
}


sub _search_hit {
	my ($plugin, $app, $entry) = @_;
	
	my $search_hit_method = $plugin->{search_hit_method};
	return 1 if &{$search_hit_method}($app, $entry); # If query matches non-CustomFields, why waste time?
	return 0 if $app->{searchparam}{SearchElement} ne 'entries'; # If it hasn't matched and isn't searching on entries, again why waste time?
	
	my @text_elements = ($entry->title, $entry->text, $entry->text_more,
                      $entry->keywords);

	require MT::PluginData;
	my $id = $entry->id;
	my $field_data = MT::PluginData->load({ plugin => 'CustomFields', key => "entry_${id}"});
	return 0 if !$field_data;
	
	foreach my $field (keys %{$field_data->data}) {
		next unless $field_data->data->{$field};
		push @text_elements, $field_data->data->{$field};
	}
	
	return 1 if $app->is_a_match(join("\n", map $_ || '', @text_elements));
}

# Upgrade functions 

sub convert_data {
	my $plugin = shift;
	my (@rows, @temp_rows); 
	
	require MT::PluginData;
	@temp_rows = MT::PluginData->load({ plugin => 'entries' });
	push @rows, @temp_rows;
	
	@temp_rows = MT::PluginData->load({ plugin => 'authors' });
	push @rows, @temp_rows;
	
	@temp_rows = MT::PluginData->load({ plugin => 'categories' });
	push @rows, @temp_rows;	
	
	require CustomFields::CustomField;
	
	# First convert the fields, these need to then be used for the actual data. 
	
	my %map; 	
	foreach my $row (@rows) {
		next unless $row->key =~ m/^field_/;
		my $field = CustomFields::CustomField->new;
		$row->data->{blog_id} ||= 0;
		$field->set_values($row->data);
		$field->name($row->data->{field});
		my $tag = $field->tag;
		if(!$tag) {
			$tag = $row->data->{field};
			$tag =~ s/(\w+)/\u\L$1/g;
			$tag =~ s/ //g;				
		}
		if($row->plugin eq 'entries') {
			$field->field_datasource('entry');
			$field->tag('EntryData'.$tag);
		} elsif($row->plugin eq 'authors') {
			$field->field_datasource('author');
			$field->tag('AuthorData'.$tag);
		} elsif($row->plugin eq 'categories') {
			$field->field_datasource('category');
			$field->tag('CategoryData'.$tag);
		}
		$field->save or die $field->errstr;
		$map{$row->data->{field}} = $field->id;			
		$row->remove or die $row->errstr;
	} 
	
	foreach my $row (@rows) {
		next if $row->key =~ m/^field_/;
		my %new_data;
		$row->plugin('CustomFields');
		foreach (keys %{$row->data}) {
			$new_data{$map{$_}} = $row->data->{$_};
		}
		$row->data(\%new_data);
		$row->save or die $row->errstr;
	}
	
}

# Author Archiving

# sub _rebuild_confirm {
# 	my ($plugin, $cb, $app, $tmpl) = @_;
# 	
#     require MT::Blog;
#     require MT::TemplateMap;
#     my $blog_id = $app->param('blog_id');
#     my $blog = MT::Blog->load($blog_id);
# 
# 	my $map_count = MT::TemplateMap->count({ blog_id => $blog_id, archive_type => 'Author' });
# 	
# 	return unless $map_count;
# 	
# 	my $old = qq{<TMPL_LOOP NAME=ARCHIVE_TYPE_LOOP>};
# 	$old = quotemeta($old);
# 	my $new = qq{<option value="Author"><MT_TRANS phrase="Rebuild Author Archives Only"></option>};
# 	
# 	$$tmpl =~ s/($old)/$new\n$1\n/;
# }

sub _cfg_archives_param {
	my($plugin, $cb, $app, $param, $tmpl) = @_;
	
	# This is mostly a cut and paste job from MT::App::CMS::cfg_archives
	
    require MT::Blog;
    require MT::TemplateMap;
    require MT::Template;
    my $blog_id = $app->param('blog_id');
    my $blog = MT::Blog->load($blog_id);	
	
	my $index = $app->config('IndexBasename');
    my $ext = $blog->file_extension || '';
    $ext = '.' . $ext if $ext ne '';
	
	my $data = $param->{archive_types};
	
	my $iter = MT::Template->load_iter({ blog_id => $blog_id });
    my(%tmpl_name);
    while (my $tmpl = $iter->()) {
        my $type = $tmpl->type;
        next unless $type eq 'archive' || $type eq 'category' ||
                    $type eq 'individual';
        $tmpl_name{$tmpl->id} = $tmpl->name;
    }

	my @map;
	
	$iter = MT::TemplateMap->load_iter({ blog_id => $blog_id, archive_type => 'Author' });
	while (my $map = $iter->()) {
		push @map, {
            map_id => $map->id,
            archive_type => $map->archive_type,
            map_template_id => $map->template_id,
            map_file_template => encode_html($map->file_template, 1),
            map_is_preferred => $map->is_preferred,
            map_template_name => $tmpl_name{ $map->template_id },
        };
	}
	
	my $tmpl_loop;
	
	foreach my $map (@map) {
	        $tmpl_loop = [
	            { name => $app->translate('author_username/') . $index . $ext, value => encode_html('<MTAuthorName dirify="1">/') . $index . $ext, default => 1 },
	            { name => $app->translate('author-username/') . $index . $ext, value => encode_html('<MTAuthorName dirify="-">/') . $index . $ext },
		        { name => $app->translate('author_nickname/') . $index . $ext, value => encode_html('<MTAuthorNickname dirify="1">/') . $index . $ext },
			    { name => $app->translate('author-nickname/') . $index . $ext, value => encode_html('<MTAuthorNickname dirify="-">/') . $index . $ext },
	        ];
	       my $custom = 1;
	       foreach (@$tmpl_loop) {
	           if ((!$map->{map_file_template} && $_->{default}) ||
	               ($map->{map_file_template} eq $_->{value})) {
	               $_->{selected} = 1;
	               $custom = 0;
	               $map->{map_file_template} = $_->{value} if !$map->{map_file_template};
	           }
	       }
	       if ($custom) {
	           unshift @$tmpl_loop, {
	               name => $map->{map_file_template},
	               value => $map->{map_file_template},
	               selected => 1,
	           };
	       }
	       $map->{archive_tmpl_loop} = $tmpl_loop;
	}
	
   push @$data, {
          archive_type_translated => $plugin->translate('Author'),
          archive_type => 'Author',
          template_map => \@map,
          map_count => (scalar @map) + 2,
          is_selected => 1,
      };
     
}

sub _cfg_archives {
	my ($plugin, $cb, $app, $tmpl) = @_;
	
	my $old = qq{<option value="Category"><MT_TRANS phrase="CATEGORY_ADV"></option>};
	$old = quotemeta($old);
	my $new = qq{<option value="Author"><MT_TRANS phrase="Author"></option>};
	
	$$tmpl =~ s/($old)/$1\n$new/;
}

sub _rebuild_pages {
	my ($plugin, $app) = @_;
	
	my $rebuild_pages_method = $plugin->{rebuild_pages_method};
	my $type = $app->param('type');
	
	return &{$rebuild_pages_method}($app) unless $type eq 'Author';
	
	&rebuild_author_archives($app);
	
	return $app->build_page('rebuilt.tmpl', { type => 'Author' });
}

sub _rebuild_entry_archive_type {
	my $plugin = shift;
	my $mt = shift;
	my (%param) = @_;

	my $at = $param{ArchiveType} or
        return $mt->error(MT->translate("Parameter '[_1]' is required",
            'ArchiveType'));

	
	if($at eq 'Author') {
		my $entry = ($param{ArchiveType} ne 'Category') ? ($param{Entry} or
	        return $mt->error(MT->translate("Parameter '[_1]' is required",
	            'Entry'))) : undef;
	
		my $app = MT->instance;
		&rebuild_author_archives($app, $entry);
		return 1;
	} else {
		my $rebuild_entry_archive_type_method = $plugin->{_rebuild_entry_archive_type_method};
		return &{$rebuild_entry_archive_type_method}($mt, %param);
	}

}

sub rebuild_author_archives {
	my $app = shift;
	
	my ($entry) = @_;
	
    require MT::Blog;
	require MT::Author;
	require MT::Entry;
    require MT::TemplateMap;
    require MT::Template;
    require MT::Builder;
    require MT::Template::Context;
    require MT::Promise;
    import MT::Promise qw(delay);
	require File::Spec;

    my $blog_id = $entry ? $entry->blog_id : $app->param('blog_id');
    my $blog = MT::Blog->load($blog_id);

	my $arch_root = $blog->archive_path || $blog->site_path;
	$arch_root .= '/' unless $arch_root =~ m!/$!;
	
	my $index = $app->config('IndexBasename');
    my $ext = $blog->file_extension || '';
    $ext = '.' . $ext if $ext ne '';

	my $terms = { type => 1 };
	$entry ? $terms->{id} = $entry->author_id : '';
	
	my $iter = MT::Author->load_iter($terms,
        { sort => 'name', direction => 'ascend', join => ['MT::Entry', 'author_id',
          { status => MT::Entry::RELEASE() }, { unique => 1 } ] });
	
    # my $iter = MT::Author->load_iter($terms, 
    # 				{'join' => ['MT::Permission', 'author_id', { blog_id => $blog_id }]} );	

	my @maps = MT::TemplateMap->load({ blog_id => $blog_id, archive_type => 'Author' });
	my $builder = MT::Builder->new;
	my $fmgr = $blog->file_mgr;
	
	while (my $author = $iter->()) {
		my $count = MT::Entry->count({blog_id => $blog->id,
                 status => MT::Entry::RELEASE(),
                 author_id => $author->id});
        next if $count == 0;

		my $entries = sub {
            my @e = MT::Entry->load({ blog_id => $blog_id,
	                                  status => MT::Entry::RELEASE(),
					    			  author_id => $author->id },
	                        		{ sort => 'created_on',
	                                  direction => 'descend' });
            \@e;
        };

		foreach my $map (@maps) {
			my $tmpl = MT::Template->load($map->template_id);
			my $filename = $map->file_template || '<MTAuthorName dirify="1">/' . $index . $ext;			
			{
				my $ctx = MT::Template::Context->new;
				$ctx->{__stash}{blog} = $blog;
			 	$ctx->{__stash}{blog_id} = $blog_id;
		     	$ctx->{__stash}{author} = $author;
	
				my $filenames = MT->instance->request('__cached_filename_tokens') || MT->instance->request('__cached_filename_tokens', {});
	            my $tokens = $filenames->{$map->id};
	           	unless ($tokens) {
	               $tokens = $builder->compile($ctx, $filename)
	                  or die $builder->errstr;
	                $filenames->{$map->id} = $tokens;
	            }

				defined($filename = $builder->build($ctx, $tokens))
			         or die $builder->errstr;

			}
			
			my $ctx = MT::Template::Context->new;
			$ctx->{__stash}{blog} = $blog;
		 	$ctx->{__stash}{blog_id} = $blog_id;
	     	$ctx->{__stash}{author} = $author;			
			$ctx->{__stash}{entries} = delay($entries);
            $ctx->{__stash}{author_entries} = delay($entries);

			my $html = $tmpl->build($ctx)
			 	or die MT->translate("Building author '[_1]' failed: [_2]",
		                                         $author->name, $tmpl->errstr);
			my $file = File::Spec->catfile($arch_root, $filename);
			
			my $path = dirname($file);
		    $path =~ s!/$!! unless $path eq '/';  ## OS X doesn't like / at the end in mkdir().
		    unless ($fmgr->exists($path)) {
		        $fmgr->mkpath($path)
		            or die $app->translate("Error making path '[_1]': [_2]",
		                                       $path, $fmgr->errstr);
		    }
					
			my $use_temp_files = !$app->config('NoTempFiles');
		    my $temp_file = $use_temp_files ? "$file.new" : $file;
		    defined($fmgr->put_data($html, $temp_file))
		        or die $app->translate("Writing to '[_1]' failed: [_2]",
		                                   $temp_file, $fmgr->errstr);
		    if ($use_temp_files) {
		        $fmgr->rename($temp_file, $file)
		            or die $app->translate("Renaming tempfile '[_1]' failed: [_2]",
		                                       $temp_file, $fmgr->errstr);
		    }

		}
	}	
	1;	
}

1;