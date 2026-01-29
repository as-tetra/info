# Copyright 2003 Stepan Riha. This code cannot be redistributed without
# permission from www.nonplus.net.

=head1 <MTCollate*> tags

Free for personal or commercial use. 

Version 1.1 - January 21, 2003
Added 'locale' attribute

Version 1.01 - September 3, 2003
Added 'distinct' attribute

Version 1.0 - May 12, 2003
Initial release

	MTCollateCollect
		MTCollateRecord
			MTCollateSetField
	MTCollateList
		MTCollateIfHeader
		MTCollateIfFooter
		MTCollateField
		MTCollatePrevious
		MTCollateNext

Example:

<!-- Build collection of entries and comments -->
<MTCollateCollect>
	<MTEntries lastn="20">
		<MTCollateRecord>
			<MTCollateSetField name="type">entry</MTCollateSetField>
			<MTCollateSetField name="date"><$MTEntryDate format="%Y-%m-%d"$></MTCollateSetField>
			<MTCollateSetField name="time"><$MTEntryDate format="%H:%M:%S"$></MTCollateSetField>
			<MTCollateSetField name="text"><$MTEntryBody$></MTCollateSetField>
		</MTCollateRecord>
	</MTEntries>
	<MTComments lastn="20">
		<MTCollateRecord>
			<MTCollateSetField name="type">comment</MTCollateSetField>
			<MTCollateSetField name="date"><$MTCommentDate format="%Y-%m-%d"$></MTCollateSetField>
			<MTCollateSetField name="time"><$MTCommentDate format="%H:%M:%S"$></MTCollateSetField>
			<MTCollateSetField name="text"><$MTCommentBody$></MTCollateSetField>
		</MTCollateRecord>
	</MTComments>
</MTCollateCollect>

<!-- display 20 most recent entries and or comments, descending by date, ascending by time -->
<MTCollateList limit="20 date:- time:-" sort="date:- time:+" locale="en_US">
	<MTCollateIfHeader name="date">
		<div class="date">
		<b><MTCollateField name="date"></b><br />
	</MTCollateIfHeader>
	<MTCollateField name="time">:
	<b><MTCollateField name="type"></b> - <MTCollateField name="text"> <br />
	<MTCollateIfFooter name="date">
		</div>
	</MTCollateIfFooter>
</MTCollateList>

=cut

## Declare modules we use
package MT::plugins::MTCollate;
use strict;
use MT::Template::Context;
use vars qw( $VERSION %COMPARE $locale );
my $VERSION = '1.1';

## Register MT handlers

MT::Template::Context->add_tag(CollateVersion => sub { $VERSION } );
MT::Template::Context->add_container_tag(CollateCollect => \&MTCollateCollect );
MT::Template::Context->add_container_tag(CollateRecord => \&MTCollateRecord );
MT::Template::Context->add_container_tag(CollateSetField => \&MTCollateSetField );
MT::Template::Context->add_container_tag(CollateList => \&MTCollateList );
MT::Template::Context->add_container_tag(CollatePrevious => \&MTCollatePrevious );
MT::Template::Context->add_container_tag(CollateNext => \&MTCollateNext );
MT::Template::Context->add_conditional_tag(CollateIfHeader => \&MTCollateIfHeader);
MT::Template::Context->add_conditional_tag(CollateIfFooter => \&MTCollateIfFooter);
MT::Template::Context->add_tag(CollateField => \&MTCollateField );

sub MTCollateCollect {
    my($ctx, $args, $cond) = @_;
	my $name = $args->{name} || '';

	## Retrieve stashed info
	my $col = $ctx->stash('mtcollate');
	if(!$col) {
		$col = {};
		$ctx->stash('mtcollate', $col);
	}

	## Let MTCollateRecord know what table to use
	my $table = [];
	local $ctx->{__stash}{'mtcollate_table'} = $table;

	## Initialize record counter
	local $col->{__counter} = 0;

	## Build
	defined($ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		or return;

	## Store Collected stuff
	if(my $record = $ctx->stash('mtcollate_record')) {
		## Nested collation, store in record
		$record->{__tables}{$name} = $table;
	} else {
		## Top-level collation, store in col
		$col->{__tables}{$name} = $table;
	}
	return '';
}

sub MTCollateRecord {
    my($ctx, $args, $cond) = @_;

	## Make sure we have a table
	my $table = $ctx->stash('mtcollate_table')
		or return $ctx->error("MTCollateRecord must be inside of MTCollateCollect");

	## Retrieve stashed info
	my $col = $ctx->stash('mtcollate');

	## Let MTCollateSetField know what record to use
	my $record = {};
	local $ctx->{__stash}{'mtcollate_record'} = $record;

	## Build
	defined($ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		or return;

	## Increment counter
	$record->{__index} = $col->{__counter}++;
	## Store Collected stuff
	push @$table, $record;

	return '';
}

sub MTCollateSetField {
    my($ctx, $args, $cond) = @_;
	my $name = $args->{name} || '';

	## Make sure we have a record
	my $record = $ctx->stash('mtcollate_record')
		or return $ctx->error("MTCollateSetField must be inside of MTCollateRecord");

	## Build
	defined(my $text = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		or return;

	## Store field
	$record->{$name} = $text;
	
	return '';
}

sub MTCollateList {
    my($ctx, $args, $cond) = @_;
	my $name = $args->{name} || '';
	my $sort = $args->{'sort'} || '';
	my $offset = $args->{offset};
	my $old_locale;
	my ($limit, $limit_sort) = split /\s+/, ($args->{limit} || ""), 2;

	$locale = $args->{locale};

	my $table;
	if(my $record = $ctx->stash('mtcollate_record')) {
		$table = $record->{__tables}{$name};
	} elsif(my $col = $ctx->stash('mtcollate')) {
		$table = $col->{__tables}{$name};
	}
	return $ctx->error("No collection '$name' exists, it must be created using 'MTCollateCollect' tags")
		unless $table;

	## Sort table
	%COMPARE = compile_compare($ctx, $limit_sort ? $limit_sort : $sort)
		or return;

	## Setup locale for proper collation
	if (defined $locale) {
		eval {
			use POSIX qw(locale_h);
			## Remember current locale
			$old_locale = setlocale(LC_COLLATE);
			## Set new one
			setlocale(LC_COLLATE, $locale);
		};
	}

	my @table = sort compare_records @$table;
	## Remove duplicates
	@table = grep { &remove_duplicates } @table if @{$COMPARE{distinct}};
	## Take care of offset
	splice(@table, 0, $offset) if $offset;
	## Take care of limit
	splice(@table, $limit) if $limit;

	if($limit_sort && $sort) {
		## Re-sort table, based on sort attribute
		%COMPARE = compile_compare($ctx, $sort)
			or return;
		## Remove duplicates specified in $sort
		@table = sort compare_records @table;
		@table = grep { &remove_duplicates } @table if @{$COMPARE{distinct}};
	}

	## Restore original locale
	if (defined $old_locale) {
		eval {
			## Restore old locale
			setlocale(LC_COLLATE, $old_locale);
		};
	}

	## Build contents
	my $out = '';
	my ($builder, $tokens) = ($ctx->stash('builder'), $ctx->stash('tokens'));
	my $prev;
	while (my $record = shift @table) {
		local $record->{__prev} = $prev;
		local $record->{__next} = $table[0];
		local $ctx->{__stash}{'mtcollate_record'} = $record;
		defined(my $text = $builder->build($ctx, $tokens, $cond))
			or return;
		$prev = $record;
		$out .= $text;
	}

	return $out;
}

sub MTCollateIfHeader {
    my($ctx, $args) = @_;
	my $record = $ctx->stash('mtcollate_record')
		or return $ctx->error("MTCollateIfHeader must be inside of MTCollateList");
	my $other = $record->{__prev} or return 1;
	my $name = $args->{name} || '';
	return ($record->{$name}||'') ne ($other->{$name}||'');
}

sub MTCollateIfFooter {
    my($ctx, $args) = @_;
	my $record = $ctx->stash('mtcollate_record')
		or return $ctx->error("MTCollateIfFooter must be inside of MTCollateList");
	my $other = $record->{__next} or return 1;
	my $name = $args->{name} || '';
	return ($record->{$name}||'') ne ($other->{$name}||'');
}

sub MTCollatePrevious {
    my($ctx, $args, $cond) = @_;
	my $record = $ctx->stash('mtcollate_record')
		or return $ctx->error("MTCollatePrevious must be inside of MTCollateList");
	defined(local $ctx->{__stash}{'mtcollate_record'} = $record->{__prev}) or return '';

	## Build
	return $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond);
}

sub MTCollateNext {
    my($ctx, $args, $cond) = @_;
	my $record = $ctx->stash('mtcollate_record')
		or return $ctx->error("MTCollateNext must be inside of MTCollateList");
	defined(local $ctx->{__stash}{'mtcollate_record'} = $record->{__next}) or return '';

	## Build
	return $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond);
}

sub MTCollateField {
    my($ctx, $args, $cond) = @_;
	my $name = $args->{name} || '';

	## Make sure we have a record
	my $record = $ctx->stash('mtcollate_record')
		or return $ctx->error("MTCollateField must be inside of MTCollateList");

	return $record->{$name} || '';
}

## Compile the sort string into an array of { name, descending, numeric, caseless, enum } hashes
sub compile_compare {
    my($ctx, $compare) = @_;
	my @tokens = split /\s+/, $compare;
	my @comp = ();
	my @distinct = ();

	while (my $term = shift(@tokens)) {
		my @terms = split /:/, $term;
		my $cmp = { name => shift @terms };
		my $enum = undef;
		my $enum_caseless = undef;
		my $distinct;

		while (my $op = shift @terms) {
			if($op eq '-' || $op eq 'ascending') {
				$cmp->{descending} = 1;
			} elsif($op eq '#' || $op eq 'numeric') {
				$cmp->{numeric} = 1;
			} elsif($op eq 'i' || $op eq 'insensitive') {
				$cmp->{caseless} = 1;
			} elsif($op eq 'd' || $op eq 'distinct') {
				$distinct = 1;
			} elsif(my ($values) = $op =~ /^\[(.+)\]$/) {
				my @values = split /,/, $values;
				$enum = {};
				$enum_caseless = {};
				my $i = 0;
				foreach my $val (@values) {
					$i++;
					$enum->{$val} = $i;
					$val = uc $val;
					$enum_caseless->{$val} = $i;
				}
			}
		}
		$cmp->{enum} = $cmp->{caseless} ? $enum_caseless : $enum if $enum;
		push @comp, $cmp;
		push @distinct, $cmp->{name} if $distinct;
	}
	return ( comp => \@comp, distinct => \@distinct, dups => {} );
}

## Check whether record is a duplicate of a previous record
sub remove_duplicates {
	my $item = "\0";
	foreach my $d (@{$COMPARE{distinct}}) {
		$item .= $_->{$d} . "\0";
	}
	return 0 if($COMPARE{dups}->{$item});
	$COMPARE{dups}->{$item} = $_;
}

## Compare two records based on $COMPARE{comp} array
sub compare_records {
	## Compare using locale info
	use locale;
	foreach my $cmp (@{$COMPARE{comp}}) {
		## Extract fields
		my $aval = $a->{$cmp->{name}} || '';
		my $bval = $b->{$cmp->{name}} || '';

		## Make case insensitive
		if ($cmp->{caseless}) {
			$aval = uc ($aval);
			$bval = uc ($bval);
		}

		## Compare values
		my $difference;
		if(my $enum = $cmp->{enum}) {
			## Enumeration compare
			my $e_aval = $enum->{$aval} || 1000;
			my $e_bval = $enum->{$bval} || 1000;
			if($e_aval==1000 && $e_bval==1000) {
				## Neither is in enumeration
				## String compare names
				$difference = $aval cmp $bval;
			} else {
				## One or both are in enumeration
				$difference = $e_aval <=> $e_bval;
			}
		} elsif($cmp->{numeric}) {
			## Numeric compare
			$difference = $aval <=> $bval;
		} else {
			## String compare
			$difference = $aval cmp $bval;
		}

		## Negate, if descending
		$difference = -$difference if $cmp->{descending};
		my $val = $aval cmp $bval;

		## Return if different
		return $difference if $difference;
	}

	## Records are equal, sort by index
	return $a->{__index} <=> $b->{__index};
}

1;
