use strict;

use Test::More tests => 2;

use_ok( 'PostgreSQL::PLPerl::Injector' );

use_ok( 'Safe' );

diag "Using Safe $Safe::VERSION\n";
