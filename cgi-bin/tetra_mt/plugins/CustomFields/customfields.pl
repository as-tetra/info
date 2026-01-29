# CustomFields - A plugin for Movable Type.
# Copyright (c) 2005-2006 Arvind Satyanarayan.

package MT::Plugin::CustomFields;

use 5.006;    # requires Perl 5.6.x
use MT 3.3;   # requires MT 3.3 or later

use base 'MT::Plugin';
our $VERSION = '2.0';
our $SCHEMA_VERSION = '2.0';

my $plugin;
MT->add_plugin($plugin = __PACKAGE__->new({
	name            => "CustomFields",
	version         => $VERSION,
	schema_version  => $SCHEMA_VERSION,
	description     => "<MT_TRANS phrase=\"Create custom entry, category and author fields\">",
	author_name     => "Arvind Satyanarayan",
	author_link     => "http://www.movalog.com/",
	plugin_link     => "http://plugins.movalog.com/customfields/",
	doc_link        => "http://plugins.movalog.com/customfields/manual",
	config_link     => '../../'.MT->config->AdminScript.'?__mode=list_customfields&amp;datasource=author',
	object_classes  => [ 'CustomFields::CustomField' ],
	upgrade_functions => {
        'customfields_convert_data' => {
            version_limit => 2.0,   # runs for schema_version < 2.0
            code => sub { runner('convert_data', 'app', @_); }
        }
    },
	app_methods => {
		'MT::App::CMS' => {
			'list_customfields' => sub { runner('list_customfields', 'app', @_); },
			'edit_customfields' => sub { runner('edit_customfields', 'app', @_); },
			'save_customfields' => sub { runner('save_customfields', 'app', @_); },
			'delete_customfields' => sub { runner('delete_customfields', 'app', @_); }
		}
	},
	app_action_links => {
        'MT::App::CMS' => [   # application the action applies to
            {
				type => 'blog',
                link => '../../'.MT->config->AdminScript.'?__mode=list_customfields&amp;datasource=entry',
                link_text => 'Configure Entry CustomFields'
            },
            {
				type => 'entry',
                link => '../../'.MT->config->AdminScript.'?__mode=list_customfields&amp;datasource=entry',
                link_text => 'Configure Entry CustomFields'
            },
            {
				type => 'blog',
                link => '../../'.MT->config->AdminScript.'?__mode=list_customfields&amp;datasource=category',
                link_text => 'Configure Category CustomFields'
            },
            {
				type => 'category',
                link => '../../'.MT->config->AdminScript.'?__mode=list_customfields&amp;datasource=category',
                link_text => 'Configure Category CustomFields'
            }
        ]
    },
	callbacks => {
		'MT::App::CMS::AppTemplateParam.edit_entry' => sub { runner('_field_loop_param', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.edit_entry' => {
			code => sub { runner('_edit_entry', 'app', @_); },
			priority => 10
		}, 
		'MT::App::CMS::AppTemplateOutput.edit_entry' => sub { runner('_edit_entry_reorder', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.entry_prefs' => sub { runner('_entry_prefs', 'app', @_); },
		'MT::Entry::pre_save' => sub { runner('pre_save', 'app', @_); },
		'MT::Entry::post_save' => sub { runner('post_save', 'app', @_); },
		'MT::App::CMS::AppTemplateParam.edit_category' => sub { runner('_field_loop_param', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.edit_category' => sub { runner('_edit_category', 'app', @_); },
		'MT::Category::pre_save' => sub { runner('pre_save', 'app', @_); },	
		'MT::Category::post_save' => sub { runner('post_save', 'app', @_); },	
		'MT::App::CMS::AppTemplateParam.edit_author' => sub { runner('_field_loop_param', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.edit_author' => sub { runner('_edit_author', 'app', @_); },	
		'MT::App::CMS::AppTemplateParam.edit_profile' => sub { $_[1]->param('_type', 'author'); runner('_field_loop_param', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.edit_profile' => sub { runner('_edit_author', 'app', @_); },
		'MT::Author::pre_save' => sub { runner('pre_save', 'app', @_); },	
		'MT::Author::post_save' => sub { runner('post_save', 'app', @_); },		
		'MT::App::CMS::AppTemplateSource.upload' => sub { runner('_upload_field_id', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.upload_confirm' => sub { runner('_upload_field_id', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.upload_complete' => sub { runner('_upload_complete', 'app', @_); },
		'MT::App::CMS::AppTemplateParam.upload_complete' => sub { runner('_upload_complete_param', 'app', @_); },
		'MT::App::CMS::AppTemplateSource.show_upload_html' => sub { runner('_show_upload_html', 'app', @_); },
		'MT::App::CMS::AppTemplateParam.show_upload_html' => sub { runner('_show_upload_html_param', 'app', @_); },
		# 'MT::App::CMS::AppTemplateSource.rebuild_confirm' => sub { runner('_rebuild_confirm', 'app', @_); }, # Fixes stupid bug
		'MT::App::CMS::AppTemplateSource.cfg_archives' => sub { runner('_cfg_archives', 'app', @_); },
		'MT::App::CMS::AppTemplateParam.cfg_archives'  => sub { runner('_cfg_archives_param', 'app', @_); },
	},
	container_tags => {
		'Authors' => sub { runner('_hdlr_authors', 'template', @_); },
		'AuthorData' => sub { runner('_hdlr_customfield_data', 'template', @_, 'author'); },
		'EntryData' => sub { runner('_hdlr_customfield_data', 'template', @_, 'entry'); },
		'CategoryData' => sub { runner('_hdlr_customfield_data', 'template', @_, 'category'); }
	},
	template_tags => {
		'AuthorID' => sub { runner('_hdlr_author_id', 'template', @_); },
		'AuthorUsername' => sub { runner('_hdlr_author_name', 'template', @_); },
		'AuthorName' => sub { runner('_hdlr_author_name', 'template', @_); },
		'AuthorDisplayName' => sub { runner('_hdlr_author_nickname', 'template', @_); },
		'AuthorNickname' => sub { runner('_hdlr_author_nickname', 'template', @_); },
		'AuthorEmail' => sub { runner('_hdlr_author_email', 'template', @_); },
		'AuthorURL' => sub { runner('_hdlr_author_url', 'template', @_); },
		'AuthorLink' => sub { runner('_hdlr_author_link', 'template', @_); },
		'AuthorPublicKey' => sub { runner('_hdlr_author_public_key', 'template', @_); },
		'AuthorBlogCount' => sub { runner('_hdlr_author_blog_count', 'template', @_); },
		'AuthorEntryCount' => sub { runner('_hdlr_author_entry_count', 'template', @_); },
		'AuthorDataFieldName' => sub { runner('_hdlr_customfield_data_field_name', 'template', @_, 'author'); },
		'AuthorDataFieldDescription' => sub { runner('_hdlr_customfield_data_field_description', 'template', @_, 'author'); },
		'AuthorDataFieldValue' => sub { runner('_hdlr_customfield_data_field_value', 'template', @_, 'author'); },
		'EntryDataFieldName' => sub { runner('_hdlr_customfield_data_field_name', 'template', @_, 'entry'); },
		'EntryDataFieldDescription' => sub { runner('_hdlr_customfield_data_field_description', 'template', @_, 'entry'); },
		'EntryDataFieldValue' => sub { runner('_hdlr_customfield_data_field_value', 'template', @_, 'entry'); },
		'CategoryDataFieldName' => sub { runner('_hdlr_customfield_data_field_name', 'template', @_, 'category'); },
		'CategoryDataFieldDescription' => sub { runner('_hdlr_customfield_data_field_description', 'template', @_, 'category'); },
		'CategoryDataFieldValue' => sub { runner('_hdlr_customfield_data_field_value', 'template', @_, 'category'); },
		'CustomFieldsResort' => sub { runner('_hdlr_customfield_resort', 'template', @_); }
	}
}));

# Allows external access to plugin object: MT::Plugin::CustomFields->instance
sub instance { $plugin; }

# Corrects bug in MT 3.31/2 <http://groups.yahoo.com/group/mt-dev/message/962>
sub init {
	my $plugin = shift;
	$plugin->SUPER::init(@_);
	MT->config->PluginSchemaVersion({})
	unless MT->config->PluginSchemaVersion;
}

sub init_app {
	my $plugin = shift;
	my ($app) = @_;
	$plugin->SUPER::init_app(@_);
	if($app->isa('MT::App::CMS')) {
		# $app->register_type('customfield', 'CustomFields::CustomField');
		# $app->add_rebuild_option({
		# 	key => 'Author',
		# 	label => $plugin->translate('Rebuild Author Archives Only'),
		# 	code => runner('rebuild_author_archives', 'app', @_)
		# });
	}
	
	{
		require MT::Builder;
		local $SIG{__WARN__} = sub {  }; 
		$plugin->{builder_build_method} = \&MT::Builder::build;
		$plugin->{cf_populated} ||= {};
		*MT::Builder::build = sub { runner('_builder_build', 'template', @_); };
		
		require MT::Template::Context;
		require MT::Template::ContextHandlers;
		$plugin->{_hdlr_entries_method} = \&MT::Template::Context::_hdlr_entries;
		*MT::Template::Context::_hdlr_entries = sub { runner('_hdlr_entries', 'template', @_); };
		$plugin->{_hdlr_categories_method} = \&MT::Template::Context::_hdlr_categories;
		*MT::Template::Context::_hdlr_categories = sub { runner('_hdlr_categories', 'template', @_); };
	}
	
	if($app->isa('MT::App::Search')) {
		{
			local $SIG{__WARN__} = sub {  }; 
			$plugin->{search_hit_method} = \&MT::App::Search::_search_hit;
			*MT::App::Search::_search_hit = sub { runner('_search_hit', 'app', @_); };
		}		
	}
	
	if($app->isa('MT::App::CMS')) {
		{
			local $SIG{__WARN__} = sub {  }; 
			$plugin->{rebuild_pages_method} = \&MT::App::CMS::rebuild_pages;
			*MT::App::CMS::rebuild_pages = sub { runner('_rebuild_pages', 'app', @_); };
			
			require MT::WeblogPublisher;
			$plugin->{_rebuild_entry_archive_type_method} = \&MT::WeblogPublisher::_rebuild_entry_archive_type;
			*MT::WeblogPublisher::_rebuild_entry_archive_type = sub { runner('_rebuild_entry_archive_type', 'app', @_); };
			
		}		
	}
}

sub runner {
    my $method = shift;
	my $class = shift;
	if($class eq 'app') {
		$class = 'CustomFields::App';
	} elsif($class eq 'template') {
		$class = 'CustomFields::Template::ContextHandlers';
	}
    eval "require $class;";
    if ($@) { die $@; $@ = undef; return 1; }
    my $method_ref = $class->can($method);
    return $method_ref->($plugin, @_) if $method_ref;
    die $plugin->translate("Failed to find [_1]::[_2]", $class, $method);
}

1;