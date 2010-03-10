use Test::More tests => 4;

BEGIN {
	use PostgreSQL::PLPerl::Injector;

	sub foo { return $_[0] + 1 }
	sub bar { return $_[0] * 2 }
	sub pkg::baz { return $_[0] * 3 }
	inject_plperl_with_names('foo', 'bar', 'pkg::baz');

	inject_plperl_with_names_from(Digest::MD5 => 'md5_hex');

}

# --- plperl initilization happens after Injector has been setup

require Safe;

my $safe = Safe->new('PLPerl'); # PostgreSQL 8.x

is $safe->reval(' foo(42) '), 43
	or diag $@;
is $safe->reval(' bar(42) '), 84
	or diag $@;
is $safe->reval(' pkg::baz(3) '), 9
	or diag $@;
is $safe->reval(' md5_hex("foo") '), 'acbd18db4cc2f85cedef654fccc4a4d8'
	or diag $@;
