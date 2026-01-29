# $Id $

use strict;
package MTTagInvoke;

sub TagInvoke {
    my($ctx, $args, $cond) = @_;
	my %args = %$args;
	$args = \%args;
	my $ti = { args => $args };

	## Capture tag name passed as argument
	if (defined $args->{tag_name}) {
		$ti->{name} = $args->{tag_name};
		delete $args->{tag_name};
	}
	
	local $ctx->{__stash}{tag_invoke} = $ti;

	## Get the parameters
	defined $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond)
		or return;
	## Get the name
	my $name = $ti->{name}
		or return $ctx->error("Missing tag_name (use 'tag_name' attribute or MTTagInvokeName)");
	## Strip leading MT, if present
	$name =~ s/^MT//;

	## Now Invoke
	return $ctx->stash('builder')->build($ctx,
				[ [ $name, $ti->{args}, $ti->{tokens}, undef, $ti->{arglist} ] ] , $cond);
}

sub TagContent {
    my $ctx = shift;
	my $ti = tag_invoke($ctx) or return;
	$ti->{tokens} = $ctx->stash('tokens');
	return '';
}

sub TagName {
    my ($ctx, undef, $cond) = @_;
	my $ti = tag_invoke($ctx) or return;
	defined($ti->{name} = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		or return;
	return '';
}

sub TagAttribute {
    my ($ctx, $args, $cond) = @_;
	my $ti = tag_invoke($ctx) or return;
	my $name = $args->{name}
		or return $ctx->error("Missing 'name' attribute");
	defined($ti->{args}->{$name} = $ctx->stash('builder')->build($ctx, $ctx->stash('tokens'), $cond))
		or return;
	push @{$ti->{arglist}}, [ $name => $ti->{args}->{$name} ];
	return '';
}

sub tag_invoke {
	my $ctx = shift;
	return $ctx->stash('tag_invoke')
		or die $ctx->error("Must be inside MTTagInvoke");
}

1;
