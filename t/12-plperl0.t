use Test::More tests => 8;

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

my $safe = Safe->new('SomeOther::Name'); # not a plperl container name

ok !$safe->reval(' foo(42) ');
like $@, qr/^Undefined subroutine/;
ok !$safe->reval(' bar(42) ');
like $@, qr/^Undefined subroutine/;
ok !$safe->reval(' pkg::baz(3) ');
like $@, qr/^Undefined subroutine/;
ok !$safe->reval(' md5_hex("foo") ');
like $@, qr/^Undefined subroutine/;
