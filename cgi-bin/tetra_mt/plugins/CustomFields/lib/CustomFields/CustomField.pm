# CustomFields - A plugin for Movable Type.
# Copyright (c) 2005-2006 Arvind Satyanarayan.

package CustomFields::CustomField;
use strict;

use MT::Object;
@CustomFields::CustomField::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
		'blog_id' => 'integer',
        'name' => 'string(255) not null',
		'description' => 'text',
		'field_datasource' => 'string(50) not null',
		'type' => 'string(50) not null',
		'tag' => 'string(255) not null',
		'default' => 'text',
		'options' => 'string(255)',
		'required' => 'boolean'
    },
    indexes => {
        blog_id => 1,
        name => 1,
        field_datasource => 1,
        type => 1,
    },
    primary_key => 'id',
    datasource => 'customfield',
});

1;
__END__