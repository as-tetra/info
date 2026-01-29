# ---------------------------------------------------------------------------
# MTPaginate
# A Plugin for MovableType
#
# ---------------------------------------------------------------------------
# This software is provided as-is and may not be redistributed without permission.
# You may use it for personal use for free.
# Commercial use requires a $20 license per installation. 
#
# Copyright (c) 2004-2007 Stepan Riha
# http://www.nonplus.net/software/mt
# ---------------------------------------------------------------------------
# $Id: MTPaginate.pl 19 2007-03-03 21:22:17Z stepan $

use strict;
package MTPlugin::Nonplus::MTPaginate;

use MT::Template::Context;

use vars qw( $VERSION );
our $VERSION = '1.28';

my $plugin;
eval {
    require MT::Plugin;
    $plugin = MT::Plugin->new({
        name => 'MTPaginate',
        description => <<EOS
Tags for breaking up long listings into multiple pages
EOS
		,
        doc_link => 'http://www.nonplus.net/software/mt/MTPaginate.htm',
        author_name => 'Stepan Riha',
        author_link => 'http://www.nonplus.net/software/mt/',
        version => $VERSION,
    });
    MT->add_plugin($plugin);
};

## Register MT handlers


MT::Template::Context->add_tag(PaginateVersion => sub { $VERSION } );
MT::Template::Context->add_container_tag(Paginate => \&MTPaginate );
MT::Template::Context->add_conditional_tag(PaginateIfMultiplePages => \&MTPaginateIfMultiplePages);
MT::Template::Context->add_conditional_tag(PaginateIfSinglePage => \&MTPaginateIfSinglePage);

MT::Template::Context->add_tag(PaginateNumPages => \&MTPaginateNumPages );
MT::Template::Context->add_tag(PaginateCurrentPage => \&MTPaginateCurrentPage );
MT::Template::Context->add_tag(PaginatePreviousPage => \&MTPaginatePreviousPage );
MT::Template::Context->add_tag(PaginateNextPage => \&MTPaginateNextPage );

MT::Template::Context->add_tag(PaginatePreviousPageLink => \&MTPaginatePreviousPageLink );
MT::Template::Context->add_tag(PaginateNextPageLink => \&MTPaginateNextPageLink );
MT::Template::Context->add_tag(PaginateAllPagesLink => \&MTPaginateAllPagesLink );
MT::Template::Context->add_tag(PaginateNavigator => \&MTPaginateNavigator );

MT::Template::Context->add_container_tag(PaginateIfPageHeader_ => \&MTPaginateIfPageHeader_ );
MT::Template::Context->add_container_tag(PaginateIfPageFooter_ => \&MTPaginateIfPageFooter_ );
MT::Template::Context->add_tag(PaginateCurrentSection => \&MTPaginateCurrentSection );
MT::Template::Context->add_tag(PaginateTopSection => \&MTPaginateTopSection );
MT::Template::Context->add_tag(PaginateBottomSection => \&MTPaginateBottomSection );
MT::Template::Context->add_tag(PaginateNumSections => \&MTPaginateNumSections );

MT::Template::Context->add_container_tag(PaginateIfFirstPage_ => \&MTPaginateIfFirstPage_ );
MT::Template::Context->add_container_tag(PaginateIfMiddlePage_ => \&MTPaginateIfMiddlePage_ );
MT::Template::Context->add_container_tag(PaginateIfNextPage_ => \&MTPaginateIfNextPage_ );
MT::Template::Context->add_container_tag(PaginateIfPreviousPage_ => \&MTPaginateIfPreviousPage_ );
MT::Template::Context->add_container_tag(PaginateIfLastPage_ => \&MTPaginateIfLastPage_ );
MT::Template::Context->add_container_tag(PaginateIfAllPages_ => \&MTPaginateIfAllPages_ );
MT::Template::Context->add_tag(PaginateElse_ => \&MTPaginateElse_ );

MT::Template::Context->add_container_tag(PaginateContent => \&MTPaginateContent );
MT::Template::Context->add_container_tag(PaginateStaticBlock => \&MTPaginateStaticBlock );
MT::Template::Context->add_container_tag(PaginateSectionID => \&MTPaginateSectionID );
MT::Template::Context->add_tag(PaginateSectionBreak => \&MTPaginateSectionBreak );
MT::Template::Context->add_tag(PaginatePageBreak => \&MTPaginatePageBreak );

my $debug = 0;

########################################################################
## PAGINATE
########################################################################

sub MTPaginate {
	require MTPaginate;
	MTPaginate::Paginate(@_);
}

sub MTPaginateIfSinglePage {
	require MTPaginate;
	MTPaginate::PaginateIfSinglePage(@_);
}

sub MTPaginateIfMultiplePages {
	require MTPaginate;
	MTPaginate::PaginateIfMultiplePages(@_);
}


########################################################################
## PAGE NAVIGATION
########################################################################

sub MTPaginatePreviousPageLink {
	require MTPaginate;
	MTPaginate::PaginatePreviousPageLink(@_);
}

sub MTPaginateNextPageLink {
	require MTPaginate;
	MTPaginate::PaginateNextPageLink(@_);
}

sub MTPaginateAllPagesLink {
	require MTPaginate;
	MTPaginate::PaginateAllPagesLink(@_);
}

sub MTPaginateNavigator {
	require MTPaginate;
	MTPaginate::PaginateNavigator(@_);
}

########################################################################
## PAGE NUMBERS
########################################################################

sub MTPaginateNumPages {
	require MTPaginate;
	MTPaginate::PaginateNumPages(@_);
}

sub MTPaginatePreviousPage {
	require MTPaginate;
	MTPaginate::PaginatePreviousPage(@_);
}

sub MTPaginateCurrentPage {
	require MTPaginate;
	MTPaginate::PaginateCurrentPage(@_);
}

sub MTPaginateNextPage {
	require MTPaginate;
	MTPaginate::PaginateNextPage(@_);
}


########################################################################
## PAGE CONDITIONS
########################################################################

sub MTPaginateIfFirstPage_ {
	require MTPaginate;
	MTPaginate::PaginateIfFirstPage_(@_);
}

sub MTPaginateIfMiddlePage_ {
	require MTPaginate;
	MTPaginate::PaginateIfMiddlePage_(@_);
}

sub MTPaginateIfAllPages_ {
	require MTPaginate;
	MTPaginate::PaginateIfAllPages_(@_);
}

sub MTPaginateIfLastPage_ {
	require MTPaginate;
	MTPaginate::PaginateIfLastPage_(@_);
}

sub MTPaginateIfPreviousPage_ {
	require MTPaginate;
	MTPaginate::PaginateIfPreviousPage_(@_);
}

sub MTPaginateIfNextPage_ {
	require MTPaginate;
	MTPaginate::PaginateIfNextPage_(@_);
}

sub MTPaginateElse_ {
	require MTPaginate;
	MTPaginate::PaginateElse_(@_);
}

########################################################################
## PAGE SECTION DONDITION
########################################################################

sub MTPaginateIfPageHeader_ {
	require MTPaginate;
	MTPaginate::PaginateIfPageHeader_(@_);
}

sub MTPaginateIfPageFooter_ {
	require MTPaginate;
	MTPaginate::PaginateIfPageFooter_(@_);
}

sub MTPaginateCurrentSection {
	require MTPaginate;
	MTPaginate::PaginateCurrentSection(@_);
}

sub MTPaginateTopSection {
	require MTPaginate;
	MTPaginate::PaginateTopSection(@_);
}

sub MTPaginateBottomSection {
	require MTPaginate;
	MTPaginate::PaginateBottomSection(@_);
}

sub MTPaginateNumSections {
	require MTPaginate;
	MTPaginate::PaginateNumSections(@_);
}

########################################################################
## PAGE CONTENT
########################################################################

sub MTPaginateContent {
	require MTPaginate;
	MTPaginate::PaginateContent(@_);
}

sub MTPaginateStaticBlock {
	require MTPaginate;
	MTPaginate::PaginateStaticBlock(@_);
}

sub MTPaginateSectionID {
	require MTPaginate;
	MTPaginate::PaginateSectionID(@_);
}

sub MTPaginateSectionBreak {
	require MTPaginate;
	MTPaginate::PaginateSectionBreak(@_);
}

sub MTPaginatePageBreak {
	require MTPaginate;
	MTPaginate::PaginatePageBreak(@_);
}

1;
