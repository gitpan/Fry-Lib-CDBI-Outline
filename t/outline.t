#!/usr/bin/perl

use strict;
use Test::More;
#use base qw/Fry::Lib::CDBI::Basic/;

BEGIN {
	eval { require DBD::Pg; };
	#eval { require Class::DBI; };
	plan skip_all => 'needs DBD::Pg for testing' if $@;
}

use lib 'lib';
use base 'Fry::Lib::CDBI::Outline';
#needed for dang parse_num
use base 'Fry::Shell';
use lib 't/testlib/';
use base 'Bmark';

#connects via Class::DBI,create temporary table and creates records
eval { __PACKAGE__->db_setup; };
plan skip_all=>"table setup failed: $@" if $@;

plan tests=>10;

#variables
	our @ISA;
#pretesting
	#define variables normally defined via shell
	__PACKAGE__->mk_many_global('flag'=>{},insertcol=>[qw/url tags notes
	name/],_print=>'');
	__PACKAGE__->mk_many_global(db=>'postgres',dbname=>$PgBase::db,tb=>__PACKAGE__->table,cols=>[@Bmark::columns]
		,printcols=>\@Bmark::columns);
	__PACKAGE__->mk_many_global(%{Fry::Lib::CDBI::Outline->_default_data->{global}});
	__PACKAGE__->mk_cdata_global(_db_default=>{postgres=>{regex=>'~'}});

	eval {require Fry::Lib::CDBI::Outline; push (@ISA,'Fry::Lib::CDBI::Outline');};
	ok (! $@,"Fry::Lib::CDBI::Outline loaded fine");
#testing
	#input2bits
	is_deeply([__PACKAGE__->input2bits(qw/perl(vim)python/)],
	[qw/,perl (vim )python/],'parsing w/ input2bits');

	#get_indents
	is_deeply([__PACKAGE__->get_indents(qw/(grandfather (father ,mother (son/)],[qw/0 1 1 2/],"&get_indents");

	#get_values
	is_deeply([__PACKAGE__->get_values(qw/,big (man )small ,noggin/)],[qw/big man small noggin/],'&get_values');

	#set_results
		#otl2select
		is_deeply([__PACKAGE__->otl2select(qw/tags=perl vim url=something/)],
		[qw/tags=perl tags=vim url=something/],'converts otl input syntax to select_abstract input');

	SKIP: { 
                eval {require Class::DBI::AbstractSearch};
                skip "Class::DBI::AbstractSearch not installed",4 if ($@);

		#set_results	
		my @obj_otl = ({qw/value vim indent 0/},{qw/value script indent 1/},
		{qw/value salsa indent 0/}); 
		__PACKAGE__->set_results(\@obj_otl);

		ok(! exists $obj_otl[0]{result},'check that no result for parent tag that has a child');
		ok($obj_otl[1]{result}->[0]->isa('Class::DBI'),'result with child and is Class::DBI obj');
		is(@{$obj_otl[2]{result}},5,'correct # of results and second search successful');

		#printnormal
		my $delim = ",,";
		my $print_result = "\t\t\t477${delim}vim_debugger$delim\n";
		is(__PACKAGE__->printnormal($obj_otl[1]{result},[qw/id notes/],2),$print_result,'&print_normal');
	}

	eval {__PACKAGE__->create_outline("vim(script)salsa")};
	ok ( ! $@,'&create_outline');
