#!/usr/bin/perl
#declarations
package Fry::Lib::CDBI::Outline;
	use strict;
	use base 'Class::Data::Global';
	our $VERSION = '0.01';

	#local
		#characters used to delimit indent level relative to previous indent
		#left-indent to the left,even-stay in same indent,right,indent to the right
		our ($left,$right,$even) = (qw/\) \( ,/);
		our $otlcol = "tags";
		our $ind;
#functions
	sub _default_data {	
		return {
			depend=>['CDBI::BDBI'],
			alias=>{
				cmds=>{qw/o normalotl/}
			},	
			global=>{
				_splitter=>'=',
				_delim=>{display=>',,'},
			},
			help=>{
				normalotl=>{ d=>'presents several database queries in an outline format',
					u=>'($query_chunk$level_delimiter)+'}
			}	
		}	
	}	
	#print
	sub printnormal {
		my $class =shift;
		my @rows = @{shift()};
		my @columns = @{shift()};
		my $indent = shift;
		my $data;
		my $ind = "\t" x ($indent + 1);

		for my $row (@rows) {
			for my $c (@columns) {
				$data .= ($row->$c || "");
				$data .= $class->_delim->{display};
			}
			$data .= "\n";
		}

		$data =~ s/^/$ind/mg;
		return $data;
	}
	#select functions
	sub parseselect_abstract {
		#d:parses userinput and produces @ for sql:abstract
		my $class =  shift;
		my @search;

		foreach (@_) {
			my ($key,$value) = split(/${\$class->_splitter}/); 
			push (@search,$key,$value);
		}
		return @search;
	}
	sub get_select_otl {
		my $class = shift; 

		eval {require Class::DBI::AbstractSearch };
		if ($@) { warn "this function needs Class::DBI::AbstractSearch: $@"; return }

		my @search = $class->parseselect_abstract(@_);
		my @results = $class->Class::DBI::AbstractSearch::search_where(\@search,{logic=>'and',
		cmp=>$class->_db_default->{$class->db}{regex}});

		return @results;
	}

	#parsing logic
	sub input2bits {
		my $class = shift;
		my $entry ="@_"; 

		$entry =~ s/[$left$right$even]$//;
		$entry =~ s/([$left$right$even])/\n\1/g;
		$entry =~ s/^/$even/;

		return split(/\n/,$entry);
	}
	sub get_indents {
		#d:create indents associated with @entry
		#increment,decrement or do nothing too match level of $ith item
		my $class = shift;
		my @entry = @_;
		my @indent;
		$indent[0]=0;

		for (my $i=1;$i <@entry;$i++) {
			for (substr($entry[$i],0,1)) {
				/^$left$/ && do {$indent[$i]=$indent[$i-1]-1;last };
				/^$right$/ && do {$indent[$i]=$indent[$i-1]+1;last};
				/^$even$/ && do {$indent[$i] = $indent[$i-1];last };
			}
		}
		return @indent;
	}
	sub get_values {
		my $class = shift;
		my @values = @_;

		for (@values) {$_ = substr($_,1);}	#chop first letters off of array
		return @values;
	}
	sub otl2select {
		#d:pass search terms to list fn,have special %% term
		my $class = shift;
		my @terms = @_;
		my (@sameterms,@normterms,$sameterm,@rows,@input);
		my $splitter = $class->_splitter;

		#parse terms
		for (@terms) {
			#(/=/) ? push(@normterms,$_) : push(@sameterms,$_)  ;
			#above line turned into below if/else

			#default tag column assumed when no splitter present
			if ($_ !~ /$splitter/) {
				push(@input,$otlcol.$splitter.$_);
			}	
			else { push(@input,$_);	}	
		}

		return @input;
	}
	sub set_results {
		#d:inserts results at proper outline levels into @tags
		my $class = shift;
		my @otl_obj = @{shift()};
		my @stack;	#stack stack for a given level
		my $max = scalar(@otl_obj);

		for (my $i=0;$i <$max;$i++) {		#creates an array of base otl_obj for next search term
			#doesn't have child	
			if ($otl_obj[$i]{indent} >= $otl_obj[$i+1]{indent}) { 
				$otl_obj[$i]{result} = [$class->get_select_otl($class->otl2select($otl_obj[$i]{value},@stack))];
			}

			#if next obj is a child (a greater indent) then add to stack
			if ($otl_obj[$i]{indent} < $otl_obj[$i+1]{indent}) {push(@stack,$otl_obj[$i]{value});}
			#if not child then pop
			elsif ($otl_obj[$i]{indent} > $otl_obj[$i+1]{indent}) {pop(@stack);}
		}
		pop(@otl_obj); 	#created accidently by autovivification
		return @otl_obj;
	} 
	sub display {
		#d:display @otl_obj in outline format
		my $class = shift;
		my @otl_obj = @_;
		my @tag;	#tag stack for a given level
		my ($body);
		my $max = scalar(@otl_obj);

		for (my $i=0;$i <$max;$i++) {		#creates an array of base otl_obj for next search term
			$ind = "\t" x $otl_obj[$i]{indent};
			$body = $ind . "$otl_obj[$i]{value}\n";

			#doesn't have child	
			if ($otl_obj[$i]{indent} >= $otl_obj[$i+1]{indent}) { 
				$body  .= $class->printnormal ($otl_obj[$i]{result},
				$class->printcols,$otl_obj[$i]{indent});
			}
		}
		return $body;
	} 
	#main function calling all the above 
	sub otlzmain {
		#d:parses input + returns outline of results
		my $class =  shift;
		my (@otl_obj);
		#@otl_obj are @ of % with indent,value and result keys

		my @bits = $class->input2bits(@_);
		my @indent = $class->get_indents(@bits);
		my @value = $class->get_values(@bits);

		#creating @ of % for otl_obj
		for (my $i=0;$i<@indent;$i++) {
			$otl_obj[$i]{value} = $value[$i];
			$otl_obj[$i]{indent} = $indent[$i];
		} 

		$class->set_results(\@otl_obj);

		my $body = $class->display(@otl_obj);

		return $body;
	}
#shell function
	sub normalotl {
		my $class = shift;
		print $class->otlzmain(@_);
	}	
1;

__END__	

=head1 NAME

CDBI::Outline.pm - A Class::DBI library of Fry::Shell for displays several database queries in an
outline format.

=head1 VERSION

This document describes version 0.01

=head1 DESCRIPTION 

This module takes a query outline and produces results in the same outline format.
To write an outline in one line for commandline apps, there is a shorthand syntax.
Take the sample outline:

	dog
		rex
		cartoon
			snoopy
			brian
	cat		

In shorthand syntax this is 'dog(rex,cartoon(snoopy,brian))cat'.		
I'll use node to refer to a line in the outline ie 'dog'.
There are three characters that delimit indent levels between nodes:

	'(':following node is indented one level
	')': following node is unindented one level
	',': following node remains at same level

Each node is a query chunk which uses the same syntax as
&Fry::Lib::CDBI::Basic::cdbi_select.  The splitter is define by the _splitter
accessor.

For example, here's a simple query outline:

	tag=perl(tag=dbi,read)name=Shell::

which means the following query outline:

	tags=perl
		tags=dbi
		read
	name=Shell::

which would produce:  

	tags=perl
		tags=dbi
			#results of tags=dbi and tags=perl
		read
			#results of tags=read and tags=perl
	name=Shell::
		#results of name=Shell:

The resulting outline produces results under the last level children. By default the query chunks
('tags=perl') are ANDed. If no $splitter ('=' here) is in a given query chunk then a default column name
is assumed by $otlcol.

Although there is no required table format I usually use this module for tables that I'm tagging.
See Fry::Lib::CDBI::Tags for more detail.

=head1 Suggested Modules

Currently this module's main function can only work if Class::DBI::AbstractSearch is installed.

=head1 TODO

Use &Fry::Shell::Lib::Basic::get_select as the search engine (same engine used by &cdbi_select).
This would support a wider variety of search logic.

=head1 SEE ALSO

L<Fry::Shell>,L<Fry::Lib::CDBI::Tags>

=head1 AUTHOR

Me. Gabriel that is. If you want to bug me with a bug: cldwalker@chwhat.com
If you like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
