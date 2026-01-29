# $Id: MTPaginate.pm 20 2007-03-03 21:37:23Z stepan $

use strict;
package MTPaginate;

use MT::Template::Context;
use MT::Util qw( remove_html decode_html encode_php );

my $debug = 0;

########################################################################
## PAGINATE
########################################################################

sub Paginate {
    my($ctx, $args, $cond) = @_;
    my $res = '';
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my %paginate = ();
    my $pg = \%paginate;
    
	## Setup parameters
    $pg->{disable} = $args->{disable};
	$pg->{page_selector} = $args->{page_selector} || 'page';
	$pg->{page_section_selector} = $args->{page_section_selector} || 'page_section';
	$pg->{mode} = $args->{mode} || 'php';
	$pg->{static_arr} = [];
	$pg->{static_hash} = {};
	my $default_page = $args->{default_page} || 1;

	## Setup context
	$ctx->stash('paginate', $pg);

	$res .= "<pre>&lt;MTPaginate&gt;</pre>" if $debug;
	if(0) {
		$res .= $builder->build($ctx, $tok, $cond);
	} elsif(1) {
		my @tokens1 = ();
		my @tokens2 = ();
		my $content = '';
		my $tokens = \@tokens1;
		my $hasContent = 0;

		foreach my $t (@$tok) {
			if($t->[0] eq 'PaginateContent') {
				return $ctx->error("MTPaginateContent: Only one content allowed!") if $hasContent;
				$hasContent = 1;
				$tokens = \@tokens2;
				return unless defined($content = $builder->build($ctx, [$t], $cond));
			} else {
				push(@$tokens, $t);
			}
		}

		if($hasContent) {
			## Break up content on page breaks
			my @raw_pages = split($pg->{page_break}, $content);
			my @pages = ();
			my $debugContent = ($debug || $args->{'debug'}) ? '<div style="padding: 0px 10px 10px 10px; border: solid 3px yellow">' : '';

			my $maxCount = $pg->{max_sections} || $pg->{max_bytes} || $pg->{max_words};
			my %section_ids;
			foreach my $raw_page (@raw_pages) {
				## Breakup raw page on section breaks
				my @raw_sections = split($pg->{section_break}, $raw_page);
				my @sections = ();

				## Breakup sections on section_start
				if(my $section_start = $pg->{section_start}) {
					$section_start = decode_html($section_start);
					foreach my $section (@raw_sections) {
						my @chunks = split /($section_start)/, $section;
						while (defined (my $chunk = shift @chunks)) {
							if($chunk eq $section_start) {
								push (@sections, $chunk . shift(@chunks));
							} else {
								push @sections, $chunk;
							}
						}
					}
				} else {
					@sections = @raw_sections;
				}
				
				## Combine sections into pages, based on maxCount
				my $count = 0;
#				my $page = "";
				my $page = [];
				my ($pageCount, $sectionCount, $pageSectionCount, $debugPage) = (0, 0, 0, '');
				foreach my $section (@sections) {
					my $sectionSize = 0;
					my $stripped_section = _strip_section($section);
					next if $stripped_section =~ /^\s*$/;
					if($pg->{max_sections}) {
						$sectionSize = 1;
					} elsif($pg->{max_bytes}) {
						$sectionSize = length($stripped_section);
					} else {
						my @words = split /[\s]+/, remove_html($stripped_section);
						$sectionSize = scalar(@words);
					}

					if($count > 0 && ($count+$sectionSize) > $maxCount) {
						if($debugContent) {
							my $p = _strip_section(join('', @$page));
							my $sz = length($p);
							my @words = split /[\s]+/, remove_html($p);
							my $words = scalar(@words);
							$pageCount++;
							$debugContent .= "<div style=\"background: yellow; margin-left: -10px; margin-right: -10px; padding: 5px 10px 5px 10px\"><b>Page $pageCount</b>, $pageSectionCount sections, $words words, $sz bytes</div>" . $debugPage;
							$debugPage = '';
							$pageSectionCount = 0;
						}
						push @pages, _process_page_sections($ctx, $page, scalar(@pages) + 1, \%section_ids);
						$count = 0;
						$page = [];
					}

					push @$page, $section;
					$count += $sectionSize;
					
					if($debugContent) {
						my $sz = length($stripped_section);
						my @words = split /[\s]+/, remove_html($stripped_section);
						my $words = scalar(@words);
						$sectionCount++;
						$pageSectionCount++;
						$debugPage .= "<div style=\"background: #FFFFAA; margin-left: -10px; margin-right: -10px; padding: 5px 10px 5px 10px\"><b>Section $sectionCount</b>, $words words, $sz bytes</div>";
						$debugPage .= $stripped_section;
					}
				}

				## last page
				push @pages, _process_page_sections($ctx, $page, scalar(@pages) + 1, \%section_ids) if($count > 0);
				if($debugContent && $count > 0) {
					my $p = _strip_section(join('', @$page));
					my $sz = length($p);
					my @words = split /[\s]+/, remove_html($p);
					my $words = scalar(@words);
					$pageCount++;
					$debugContent .= "<div style=\"background: yellow; margin-left: -10px; margin-right: -10px; padding: 5px 10px 5px 10px\"><b>Page $pageCount</b>, $pageSectionCount sections, $words words, $sz bytes</div>" . $debugPage;
					$debugPage = '';
					$pageSectionCount = 0;
				}
			}

			my $page_selector = $pg->{page_selector};
			my $page_section_selector = $pg->{page_section_selector};
			my $numPages = @pages;
			$pg->{num_pages} = $numPages;
			if($pg->{mode} eq 'cgi') {
				## Get page number from $_GET
				use CGI;
				$pg->{query} = CGI->new;
				my $current_page = $section_ids{$pg->{query}->param($page_section_selector)}
					|| $pg->{query}->param($page_selector) || 0;
				if($current_page ne 'all') {
					if($current_page eq 'first') {
						$current_page = 1;
					} elsif($current_page eq 'last') {
						$current_page = $numPages;
					} elsif($current_page < 1) {
						$current_page = 1;
					} elsif($current_page > $numPages) {
						$current_page = $numPages;
					}			
				}
				$pg->{current_page} = $current_page;

				my $paginate_self = '&' . $ENV{QUERY_STRING} . '&';
				$paginate_self =~ s/&$page_selector=[^&]*&/&/;
				$paginate_self =~ s/^&//;
				$paginate_self = '' if($paginate_self eq '&');
				$pg->{paginate_self} = "?$paginate_self$page_selector";

			} elsif($pg->{mode} eq 'php') {
				## Set up PHP variables: paginate_current_page ("2") and paginate_self ("/blog/page.pgp?page")
				$res .=<<PHP;
<?php if (false) : ?>
<div style="border: 2px solid red; background: yellow; margin: 1em; padding: 1em; font-family: sans-serif;">The <b>MTPaginate</b> tag only works within PHP documents!
<br />
Make sure that the document extension is <b>.php</b> and that your server supports PHP documents.
</div>
<?php endif; ?>
<?php
// Values that can be used in other PHP code on the page
\$paginate_num_pages = $numPages;
\$paginate_num_sections = __PAGINATE_NUM_SECTIONS__;
\$paginate_section_ids = array(
PHP
				foreach my $section_id (keys %section_ids) {
					my $page_num = $section_ids{$section_id};
					$section_id = encode_php($section_id);
					$res .=<<PHP;
	'$section_id' => $page_num,
PHP
				}

				$res .=<<PHP;
);
\$paginate_page_selector = '$page_selector';
\$paginate_page_section_selector = '$page_section_selector';
\$paginate_current_page_section = \@\$_GET[\$paginate_page_section_selector];
if(\$paginate_current_page_section)
	\$paginate_current_page = \@\$paginate_section_ids[\$paginate_current_page_section];
else
	\$paginate_current_page = \@\$_GET[\$paginate_page_selector];
// Pin page selector to a valid number (or 'all')
if(\$paginate_current_page=='')
	\$paginate_current_page = '$default_page';
if(\$paginate_current_page != 'all') {
	if(\$paginate_current_page == 'first')
		\$paginate_current_page = 1;
	elseif(\$paginate_current_page == 'last')
		\$paginate_current_page = $numPages;
	elseif(\$paginate_current_page < 1)
		\$paginate_current_page = 1;
	elseif(\$paginate_current_page > $numPages)
		\$paginate_current_page = $numPages;
__PAGINATE_PHP_SECTIONS__
	\$paginate_top_section = \$paginate_sections[\$paginate_current_page-1]+1;
	\$paginate_bottom_section = \$paginate_sections[\$paginate_current_page];
} else {
	\$paginate_top_section = 1;
	\$paginate_bottom_section = __PAGINATE_NUM_SECTIONS__;
}
if(isset(\$_SERVER['QUERY_STRING'])) {
	\$paginate_self = '&' . \$_SERVER['QUERY_STRING'] . '&';
	\$paginate_self = preg_replace("/&$page_selector=[^&]*&/", "&", \$paginate_self);
	\$paginate_self = preg_replace("/&$page_section_selector=[^&]*&/", "&", \$paginate_self);
	\$paginate_self = substr(\$paginate_self, 1, strlen(\$paginate_self) - 1);
	if(\$paginate_self == '&')
		\$paginate_self = '';
	else
		\$paginate_self = htmlentities(\$paginate_self);
} else {
	\$paginate_self = '';
}
PHP

				my $base_address = $args->{'base_address'} || '_relative';
				if($base_address eq '_absolute') {
					$res .=<<PHP;
\$paginate_self = \$_SERVER['PHP_SELF'] . "?\${paginate_self}$page_selector";
\$paginate_self =  'http://' . \$_SERVER['SERVER_NAME'] . (\$_SERVER['SERVER_PORT'] == 80 ? '' : \$_SERVER['SERVER_PORT']) . \$paginate_self;
PHP
				} elsif($base_address eq '_relative') {
					$res .=<<PHP;
\$paginate_self = basename(\$_SERVER['PHP_SELF']) . "?\${paginate_self}$page_selector";
PHP
				} else {
					$res .=<<PHP;
\$paginate_self = "$base_address?\${paginate_self}$page_selector";
PHP
				}
				$res .=<<PHP;
?>
PHP
			}

			## Generate content BEFORE <MTPaginateContent>
			{
				my $sub;
				return unless defined ($sub = $builder->build($ctx, \@tokens1, $cond));
				$res .= $sub;
			}

			## Generate content INSIDE <MTPaginateContent>
			$res .= "<pre>CONTENT START $numPages</pre>" if $debug;
			my $pagecount = 0;
			my $sectionCount = 0;
			my ($topSection, $bottomSection) = (1) if $pg->{mode} ne 'php';
			my $phpSections =<<PHP if($pg->{mode} eq 'php');
\$paginate_sections = array( 0
PHP
			foreach my $page (@pages) {
				my $section_ids;
				$pagecount++;
				$page = _post_process_sections($pg, $page, $pagecount == 1, $pagecount == $numPages, \$sectionCount);
				if($pg->{mode} eq 'php') {
					$res .=<<PHP;
<?php if(\$paginate_current_page == $pagecount || \$paginate_current_page == 'all') : ?>
$page
<?php endif; ?>
PHP
					$phpSections .= ", $sectionCount";
				} elsif($pg->{mode} eq 'cgi') {
					$topSection = $sectionCount if $pagecount+1 eq $pg->{current_page};
					$bottomSection = $sectionCount if $pagecount eq $pg->{current_page};
					$res .= $page if($pg->{current_page} eq 'all' || $pagecount == $pg->{current_page});
				}
			}
			$res =~ s/__PAGINATE_NUM_SECTIONS__/$sectionCount/g;
			if($pg->{mode} eq 'php') {
				$phpSections .= ");";
				$res =~ s/__PAGINATE_PHP_SECTIONS__/$phpSections/g;
			} else {
				$bottomSection = $sectionCount unless $bottomSection;
				$res =~ s/__PAGINATE_TOP_SECTION__/$topSection/g;
				$res =~ s/__PAGINATE_BOTTOM_SECTION__/$bottomSection/g;
			}

			$res .= $debugContent . "</div>" if $debugContent;
			$res .= "<pre>CONTENT END</pre>" if $debug;
			## Generate conten AFTER </MTPaginateContent>
			{
				my $sub;
				return unless defined($sub = $builder->build($ctx, \@tokens2, $cond));
				$res .= $sub;
			}
		} else {
			## No <MTPaginateContent> section, do default stuff
			$pg->{num_pages} = 1;
			{
				my $sub;
				return unless defined($sub = $builder->build($ctx, $tok, $cond));
				$res .= $sub;
			}
		}
	}
	$res .= "<pre>&lt;/MTPaginate&gt;</pre>" if $debug;

	## Cleanup
	$ctx->stash('paginate', undef);

	return $res;
}

sub PaginateIfSinglePage {
    my($ctx) = @_;
    my $pg = _get_paginate($ctx) or return;
    return $pg->{num_pages} <= 1;
}

sub PaginateIfMultiplePages {
    my($ctx) = @_;
    my $pg = _get_paginate($ctx) or return;    
    return $pg->{num_pages} > 1;
}


########################################################################
## PAGE NAVIGATION
########################################################################

sub PaginatePreviousPageLink {
    my $pg = _get_paginate(@_) or return;
	my $page_selector = $pg->{page_selector};
	if($pg->{mode} eq 'php') {
		return <<PHP;
<?php if(\$paginate_current_page > 1) echo "\$paginate_self=" . (\$paginate_current_page-1); ?>
PHP
	} else {
		my $current_page = $pg->{current_page};
		return ($current_page ne 'all' && $current_page > 1) ? $pg->{paginate_self} . '=' . ($current_page-1) : '';
	} 
}

sub PaginateNextPageLink {
    my $pg = _get_paginate(@_) or return;
	my $page_selector = $pg->{page_selector};
	my $num_pages = $pg->{num_pages};
	if($pg->{mode} eq 'php') {
		return <<PHP;
<?php if(\$paginate_current_page < $num_pages) echo "\$paginate_self=" . (\$paginate_current_page+1); ?>
PHP
	} else {
		my $current_page = $pg->{current_page};
		return ($current_page ne 'all' && $current_page < $pg->{num_pages}) ? $pg->{paginate_self} . '=' . ($current_page+1) : '';
	} 
}

sub PaginateAllPagesLink {
    my $pg = _get_paginate(@_) or return;
	my $page_selector = $pg->{page_selector};
	my $num_pages = $pg->{num_pages};
	if($pg->{mode} eq 'php') {
		return <<PHP;
<?php "\$paginate_self=all"; ?>
PHP
	} else {
		return $pg->{paginate_self} . '=all';
	} 
}

sub PaginateNavigator {
    my($ctx, $args) = @_;
    my $pg = _get_paginate($ctx) or return;
	my $list_pages = $args->{list_pages} || 'all';
	my $format = decode_html($args->{format}) || "&nbsp;%d&nbsp;";
	my $format_current = decode_html($args->{format_current}) || $format;
	my $separator = $args->{separator} || ' | ';
	my $res = '';
	my $page_selector = $pg->{page_selector};
	my $num_pages = $pg->{num_pages};
	my $format_all = decode_html($args->{format_all});
	my $format_all_current = decode_html($args->{format_all_current}) || $format_all;
	my $format_all_title = decode_html($args->{format_all_title});
	my $place_all = $args->{place_all} || 'before';
	my $start = ($list_pages eq 'after') ? '$paginate_current_page+1' : 1;
	my $end = ($list_pages eq 'before') ? '$paginate_current_page-1' : $num_pages;
	my $all_current = sprintf("$format_all_current", $num_pages);
	my $all = sprintf("$format_all", $num_pages);
	my $anchor = $args->{anchor} ? $args->{anchor} : '';
	my $format_title = $args->{format_title} || "";

	if($args->{style} && $args->{style} eq 'popup') {		
		$res =<<PHP unless $list_pages eq 'all';
<?php if($start < $end) : ?>
PHP
		$res .=<<PHP;
<select onchange="location.href=options[selectedIndex].value">
<?php
PHP
		$res .=<<PHP if $format_all && $place_all ne 'after';
	if(\$paginate_current_page == 'all') {
		echo sprintf("<option value=\\"\$paginate_self=all$anchor\\" selected>$format_all_current</option>", $num_pages);
	} else {
		echo sprintf("<option value=\\"\$paginate_self=all$anchor\\">$format_all</option>", $num_pages);
	}
PHP
		$res .=<<PHP;
for(\$i = $start; \$i <= $end; \$i++) {
	if(\$i == \$paginate_current_page) {
		echo sprintf("<option value=\\"\$paginate_self=\$i$anchor\\" selected>$format_current</option>", \$i);
	} else {
		echo sprintf("<option value=\\"\$paginate_self=\$i$anchor\\">$format</option>", \$i);
	}
}
PHP
		$res .=<<PHP if $format_all && $place_all eq 'after';
	if(\$paginate_current_page == 'all') {
		echo sprintf("<option value=\\"\$paginate_self=all$anchor\\" selected>$format_all_current</option>", $num_pages);
	} else {
		echo sprintf("<option value=\\"\$paginate_self=all$anchor\\">$format_all</option>", $num_pages);
	}
PHP
		$res .=<<PHP;
?>
</select>
PHP
		$res .=<<PHP unless $list_pages eq 'all';
<?php endif; ?>
PHP
	} else {
		my $target = $args->{target} || "";
		if($pg->{mode} eq 'cgi') {
			$target = " target=\"$target\"" if $target;
			if ($format_all && $place_all ne 'after') {
				my $title = "";
				$title =  sprintf(" title=\"$format_all_title\"", $num_pages) if $format_all_title;
				if($pg->{current_page} eq 'all') {
					$res .= "$all_current$separator";
				} else {
					$res .= "<a href=\"" . $pg->{paginate_self} . "=all$anchor\"$title$target>$all</a>$separator";
				}
			}

			$start = ($list_pages eq 'after') ? $pg->{current_page}+1 : 1;
			$end = ($list_pages eq 'before') ? $pg->{current_page}-1 : $num_pages;
			$format_title = " title=\"$format_title\"" if $format_title;
			for(my $i = $start; $i <= $end; $i++) {
				$res .= $separator if($i > $start);
				if($i eq $pg->{current_page}) {
					$res .= sprintf("$format_current", $i);
				} else {
					$res .= "<a href=\"" . $pg->{paginate_self} . "=$i$anchor\"$target" .  sprintf($format_title, $i) .  sprintf(">$format", $i) . '</a>';
				}
			}

			if ($format_all && $place_all eq 'after') {
				my $title = "";
				$title =  sprintf(" title=\"$format_all_title\"", $num_pages) if $format_all_title;
				if($pg->{current_page} eq 'all') {
					$res .="$all_current$separator";
				} else {
					$res .= "<a href=\"" . $pg->{paginate_self} . "=all$anchor\"$title$target>$all</a>$separator";
				}
			}
		} else {
			$target = " target=\\\"$target\\\"" if $target;
			$res = "<?php\n";
			if ($format_all && $place_all ne 'after') {
				my $title = "";
				$title =  sprintf(" title=\\\"$format_all_title\\\"", $num_pages) if $format_all_title;
				$res .=<<PHP
	if(\$paginate_current_page == 'all') {
		echo '$all_current$separator';
	} else {
		echo "<a href=\\\"\$paginate_self=all$anchor\\\"$title$target>$all</a>$separator";
	}
PHP
			}
			
			$format_title = " . sprintf(' title=\"$format_title\"', \$i)" if $format_title;
			$res .=<<PHP;
for(\$i = $start; \$i <= $end; \$i++) {
	if(\$i > $start)
		echo '$separator';
	if(\$i == \$paginate_current_page) {
		echo sprintf("$format_current", \$i);
	} else {
		echo "<a href=\\\"\$paginate_self=\$i$anchor\\\"$target" $format_title .  sprintf('>$format', \$i) . '</a>';
	}
}
PHP
			if ($format_all && $place_all eq 'after') {
				my $title = "";
				$title =  sprintf(" title=\\\"$format_all_title\\\"", $num_pages) if $format_all_title;
				$res .=<<PHP
	if(\$paginate_current_page == 'all') {
		echo '$separator$all_current';
	} else {
		echo "$separator<a href=\\\"\$paginate_self=all$anchor\\\"$title$target>$all</a>";
	}
PHP
			}
			$res .=<<PHP;
?>
PHP
		}
	}
	return $res;
}

########################################################################
## PAGE NUMBERS
########################################################################

sub PaginateNumPages {
    my $pg = _get_paginate(@_) or return;
	return $pg->{num_pages};
}

sub PaginatePreviousPage {
    my $pg = _get_paginate(@_) or return;
    if($pg->{mode} eq 'php') {
		return <<PHP;
<?php if(\$paginate_current_page > 1) echo \$paginate_current_page-1; ?>
PHP
	} else {
		my $current_page = $pg->{current_page};
		return ($current_page ne 'all' && $current_page > 1) ? $current_page-1 : '';
	} 
}

sub PaginateCurrentPage {
    my $pg = _get_paginate(@_) or return;
	return <<PHP;
<?php echo \$paginate_current_page; ?>
PHP
}

sub PaginateNextPage {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	if($pg->{mode} eq 'php') {
		return <<PHP;
<?php if(\$paginate_current_page < $num_pages) echo \$paginate_current_page+1; ?>
PHP
	} else {
		my $current_page = $pg->{current_page};
		return ($current_page ne 'all' && $current_page < $pg->{num_pages}) ? $current_page+1 : '';
	} 
}


########################################################################
## PAGE CONDITIONS
########################################################################

sub PaginateIfFirstPage_ {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	return _if_condition("true", @_) if($num_pages == 1);
	return _if_condition("\$paginate_current_page==1", @_);
}

sub PaginateIfMiddlePage_ {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	return _if_condition("false", @_) if($num_pages == 1);
	return _if_condition("\$paginate_current_page != 'all' && \$paginate_current_page>1 && \$paginate_current_page < $num_pages", @_);
}

sub PaginateIfAllPages_ {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	return _if_condition("false", @_) if($num_pages == 1);
	return _if_condition("\$paginate_current_page == 'all'", @_);
}

sub PaginateIfLastPage_ {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	return _if_condition("true", @_) if($num_pages == 1);
	return _if_condition("\$paginate_current_page==$num_pages", @_);
}

sub PaginateIfPreviousPage_ {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	return _if_condition("false", @_) if($num_pages == 1);
	return _if_condition("\$paginate_current_page != 'all' && \$paginate_current_page>1", @_);
}

sub PaginateIfNextPage_ {
    my $pg = _get_paginate(@_) or return;
	my $num_pages = $pg->{num_pages};
	return _if_condition("false", @_) if($num_pages == 1);
	return _if_condition("\$paginate_current_page != 'all' && \$paginate_current_page<$num_pages", @_);
}

sub PaginateElse_ {
	my $ctx = $_[0];
    my $pg = _get_paginate($ctx) or return;
	my $iflevel = $pg->{iflevel};
	if(!$iflevel) {
		my $iftag = $pg->{iftag};
		return $ctx->error("MTPaginateElse_ Must be inside an MTPaginateIf*_ tag!") unless defined $iftag;
		return $ctx->error("Multiple MTPaginateElse_ tags within a $iftag tag!")
	}
	$pg->{iflevel} = $iflevel-1;
	my $iftag = ($pg->{iftag}||'');
	if($pg->{mode} eq 'php' &&  ($iftag !~ /IfPage/)) {
		return <<PHP
<?php else: /* $iftag */ ?>
PHP
	} 
##	if($pg->{mode} eq 'cgi')
		return '__PAGINATE_ELSE__';
}

########################################################################
## PAGE SECTION DONDITION
########################################################################

sub PaginateIfPageHeader_ {
	my $sub;
	return unless defined ($sub = _if_page_condition(@_));
	return "__PAGINATE_PAGE_TOP_BEGIN__${sub}__PAGINATE_PAGE_TOP_END__";
}

sub PaginateIfPageFooter_ {
	my $sub;
	return unless defined ($sub = _if_page_condition(@_));
	return "__PAGINATE_PAGE_BOTTOM_BEGIN__${sub}__PAGINATE_PAGE_BOTTOM_END__";
}

sub PaginateCurrentSection {
    my $pg = _get_paginate(@_) or return;
	return "__PAGINATE_CURRENT_SECTION__";
}

sub PaginateTopSection {
    my $pg = _get_paginate(@_) or return;
	if($pg->{mode} eq 'php') {
		return '<?php echo $paginate_top_section; ?>';
	} else {
		return "__PAGINATE_TOP_SECTION__";
	}
}

sub PaginateBottomSection {
    my $pg = _get_paginate(@_) or return;
	if($pg->{mode} eq 'php') {
		return '<?php echo $paginate_bottom_section; ?>';
	} else {
		return "__PAGINATE_BOTTOM_SECTION__";
	}
}

sub PaginateNumSections {
    my $pg = _get_paginate(@_) or return;
	return "__PAGINATE_NUM_SECTIONS__";
}

########################################################################
## PAGE CONTENT
########################################################################

sub PaginateContent {
    my($ctx, $args, $cond) = @_;
    my $pg = _get_paginate($ctx) or return;

	$pg->{max_sections} = $args->{max_sections};
	$pg->{max_bytes} = $args->{max_bytes};
	$pg->{max_words} = $args->{max_words} || 400;
	$pg->{section_start} = decode_html($args->{section_start}) if $args->{section_start};
	$pg->{section_start} = '<' . decode_html($args->{section_start_tag}) . '>' if $args->{section_start_tag};
	$pg->{section_break} = decode_html($args->{section_break} || '__MTPAGINATE_SECTION_BREAK__');
	$pg->{page_break} = decode_html($args->{page_break} || '__MTPAGINATE_PAGE_BREAK__');

	_pass_through(@_);
}

sub PaginateStaticBlock {
    my($ctx, $args, $cond) = @_;
    my $pg = _get_paginate($ctx) or return;
	my $tokens = $ctx->stash('tokens');
	
	## Ignore empty blocks
	return "" unless @$tokens;
	
	## Get first sub-token as ID
	my $template_id = $tokens->[0];
	
	my $block = $pg->{static_hash}->{$template_id};
	if(!$block) {
		$block = new MTPaginate::StaticBlock(args => $args, cond => $cond, tokens => $tokens);
		push @{$pg->{static_arr}}, $block;
		$block->{id} = scalar @{$pg->{static_arr}};
		$pg->{static_hash}->{$template_id} = $block;
	}

	my $id = $block->{id};
	
	"__MTPAGINATE_STATIC_BLOCK[$id]STATIC_BLOCK__";
}

sub PaginateSectionID {
    my($ctx, $args, $cond) = @_;
    my $pg = _get_paginate($ctx) or return;
    my $id;
    
	return unless defined ($id = _pass_through(@_));
    
    return "__MTPAGINATE_SECTION_ID[$id]SECTION_ID__";
}

sub PaginateSectionBreak {
    my($ctx, $args) = @_;
    my $pg = _get_paginate($ctx) or return;
	my $sep = $pg->{section_break};
	if(!$sep) {
		warn "MTPaginateSectionBreak outside of MTPaginateContent";
		return '';
	}
	$sep;
}

sub PaginatePageBreak {
    my($ctx, $args) = @_;
    my $pg = _get_paginate($ctx) or return;
	my $sep = $pg->{page_break};
	if(!$sep) {
		warn "MTPaginatePageBreak outside of MTPaginateContent";
		return '';
	}
	$sep;
}

########################################################################
## HELPER FUNCTIONS
########################################################################

sub _if_condition {
	my $cond = shift;
	my $ctx = $_[0];
    my $pg = _get_paginate($ctx) or return;
	my $res = '';
	my $iflevel = $pg->{iflevel};
	my $iftag = $pg->{iftag};
    my $tag = $ctx->stash('tag');

	$pg->{iflevel} = defined($iflevel) ? $iflevel+1 : 1;
	$pg->{iftag} = $ctx->stash($tag);
	if($pg->{mode} eq 'php') {
		$res .=<<PHP;
<?php if($cond) : ?>
PHP
	}
	
	{
		my $sub;
		return unless defined ($sub = _pass_through(@_));
		if($pg->{mode} eq 'cgi') {
			if($cond eq 'true') {
				$cond = 1;
			} elsif($cond eq 'false') {
				$cond = 0;
			} else {
				my $paginate_current_page = $pg->{current_page};
				my $num_pages = $pg->{num_pages};
				$cond =~ s/==/eq/g;
				$cond =~ s/!=/ne/g;
#				warn $cond;
				$cond  = eval $cond || 0;
#				warn $cond;
			}
			my @branches = split /__PAGINATE_ELSE__/, $sub;
#			warn $branches[0];
#			warn $branches[1];
			$res .= $branches[0] if $cond;
			$res .= $branches[1] if !$cond && $#branches > 0;
		} else {
			$res .= $sub;
		}
	}
	
	if($pg->{mode} eq 'php') {
		$res .=<<PHP;
<?php endif; ?>
PHP
	}
	
	# Restore
	$pg->{iflevel} = $iflevel;
	$pg->{iftag} = $iftag;
	return $res;
}

sub _if_page_condition {
	my $ctx = $_[0];
    my $pg = _get_paginate($ctx) or return;
	my $res = '';
	my $iflevel = $pg->{iflevel};
	my $iftag = $pg->{iftag};
    my $tag = $ctx->stash('tag');

	$pg->{iflevel} = defined($iflevel) ? $iflevel+1 : 1;
	$pg->{iftag} = $ctx->stash('tag');
	
	return unless defined ($res = _pass_through(@_));
	
	# Restore
	$pg->{iflevel} = $iflevel;
	$pg->{iftag} = $iftag;
	return $res;
}

sub _not_in_paginate_error {
    my($ctx) = @_;
    my $tag = $ctx->stash('tag');
    return $ctx->error("$tag must be inside the MTPaginate tag!");
}

sub _get_paginate {
    my($ctx) = @_;
    my $pg = $ctx->stash('paginate');
    return _not_in_paginate_error($ctx) unless defined($pg);
    return $pg;
}

sub _pass_through {
    my($ctx, $args, $cond) = @_;
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');

	return $builder->build($ctx, $tok, $_[2]);
}


sub _strip_section {
	my($section) = @_;
	my $re_placeholders = qr/(__PAGINATE_CURRENT_SECTION__|__PAGINATE_TOP_SECTION__|__PAGINATE_BOTTOM_SECTION__|__PAGINATE_NUM_SECTIONS__)|__PAGINATE_PAGE_TOP_BEGIN__|__PAGINATE_PAGE_TOP_END__|__PAGINATE_PAGE_BOTTOM_BEGIN__|__PAGINATE_PAGE_BOTTOM_END__|__MTPAGINATE_SECTION_ID\[.*?\]SECTION_ID__|__MTPAGINATE_STATIC_BLOCK\[.*?\]STATIC_BLOCK__/;
	my @chunks = split $re_placeholders, $section;
	my $stripped = '';
	while (defined(my $chunk = shift(@chunks))) {
		$stripped .= $chunk;
		
		## Placeholders that will be replaced with a number
		$stripped .= '0' if (shift @chunks);
	}
	
	return $stripped;
}

sub _post_process_sections {
	my ($pg, $sections, $firstPage, $lastPage, $sectionCount) = @_;
	my $currentSection = 0;
	my $lastSection = scalar(@$sections) - 1;
	my $res = '';
	my $topSection = ${$sectionCount} + 1;

	foreach my $section (@$sections) {
		my @chunks = split /__PAGINATE_PAGE_TOP_BEGIN__|__PAGINATE_PAGE_TOP_END__/, $section;
		$section = '';
		while (defined(my $chunk = shift(@chunks))) {
			$section .= $chunk;
			if(defined($chunk = shift(@chunks))) {
				my ($true, $false) = split /__PAGINATE_ELSE__/, $chunk;
				$false = '' unless defined($false);
				if($firstPage && $currentSection == 0) {
					$section .= $true;
				} elsif($currentSection > 0) {
					$section .= $false;
				} else {
					if($pg->{mode} eq 'php') {
						if($currentSection == 0) {
							$section .=<<PHP;
<?php if(\$paginate_current_page != 'all') : /* page header */ ?>$true
PHP
							$section .=<<PHP if ($false ne '');
<?php else : /* not page header */ ?>$false
PHP
							$section .= "<?php endif; /* page header */ ?>";
						} else {
							$section .= $false;
						}
					} else {
						$section .= ($currentSection == 0 && $pg->{current_page} ne 'all') ? $true : $false;
					}
				}
			}
		}

		@chunks = split /__PAGINATE_PAGE_BOTTOM_BEGIN__|__PAGINATE_PAGE_BOTTOM_END__/, $section;
		$section = '';
		while (defined(my $chunk = shift(@chunks))) {
			$section .= $chunk;
			if(defined($chunk = shift(@chunks))) {
				my ($true, $false) = split/__PAGINATE_ELSE__/, $chunk;
				$false = '' unless defined($false);
				if($lastPage && $currentSection == $lastSection) {
					$section .= $true;
				} elsif($currentSection < $lastSection) {
					$section .= $false;
				} else {
					if($pg->{mode} eq 'php') {
						if($currentSection == $lastSection) {
							$section .=<<PHP;
<?php if(\$paginate_current_page != 'all') : /* page footer */ ?>$true
PHP
							$section .=<<PHP if ($false ne '');
<?php else : /* not page footer */ ?>$false
PHP
							$section .= "<?php endif; /* page footer */ ?>";
						} else {
							$section .= $false;
						}
					} else {
						$section .= ($currentSection == $lastSection && $pg->{current_page} ne 'all') ? $true : $false;
					}
				}
			}
		}

		$currentSection++;
		${$sectionCount}++;
		$section =~ s/__PAGINATE_CURRENT_SECTION__/${$sectionCount}/g;
		
		$res .= $section;
	}

	return $res;
}

sub _process_page_sections {
	my ($ctx, $sections, $page_no, $section_ids) = @_;
	my $page;
	my $re_ids = qr/__MTPAGINATE_SECTION_ID\[(.*?)\]SECTION_ID__/;
	my $re_blocks = qr/__MTPAGINATE_STATIC_BLOCK\[(.*?)\]STATIC_BLOCK__/;
    my $pg = _get_paginate($ctx) or return;

	my $section_count = 0;
	foreach my $section (@$sections) {
		$section_count++;
		my $res = "";
		{
			my @chunks = split $re_ids, $section;
			while (defined (my $chunk = shift @chunks)) {
				$res .= $chunk;
				$section_ids->{$chunk} = $page_no if defined ($chunk = shift @chunks);
			}
		}
		
		{
			my @chunks = split $re_blocks, $res;
			$res = '';
			while (defined (my $chunk = shift @chunks)) {
				$res .= $chunk;
				my $block_id = shift @chunks;
				if($block_id) {
					my $block = $pg->{static_arr}->[$block_id-1];

					$res .= $block->build($ctx) if $block->is_visible($page_no, $section_count);
				}
			}
		}
		
		push @$page, $res;
	}
	
	return $page;
}

package MTPaginate::StaticBlock;

## Construct a new StaticBlock object with the following properties:
##	sections: hash whose keys are the section # on which to display the block
##	pages: hash whose keys are the explicit pages on which to display the block
##	all_pages: scalar that indicates the smallest page # after which all pages display the block
sub new {
    my($class, %members) = @_;
    
    my $self = bless \%members, $class;
    
	# Process section="1, 2, 5" argument
	my @sections = split /[\s\,]+/, ($self->{args}->{section} || '');
	my %sections = map { ($_ => 1); } @sections;
	$self->{sections} = \%sections;
    
    # Process page="1" or page="2, *" argument
    
    $self->{all_pages} = 1;
    if($self->{args}->{page}) {
		my @pages = split /[\s\,]+/, $self->{args}->{page};
		my %pages = map { ($_ => 1); } @pages;
		$self->{all_pages} = 99999;
		$self->{all_pages} = $pages[-2] if($pages[-1] eq '*');
		$self->{pages} = \%pages;
    }
    
	$self;
}

## Test whether the block should be displayed in the specified page/section
sub is_visible {
	my ($self, $page, $section) = @_;
	
	# make sure section visible on this $page
	return unless $page >= $self->{all_pages} || $self->{pages}->{$page};

	$self->{sections}->{$section};
}

## Generate the content of the static block
sub build {
	my ($self, $ctx) = @_;
	
    my $builder = $ctx->stash('builder');
    my ($args, $cond, $tokens) = ($self->{args}, $self->{cond}, $self->{tokens});

	return $builder->build($ctx, $tokens, $cond);
}

1;
