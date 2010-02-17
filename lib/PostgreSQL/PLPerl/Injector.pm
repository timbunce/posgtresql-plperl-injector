package PostgreSQL::PLPerl::Injector;

=head1 NAME

PostgreSQL::PLPerl::Injector - Inject subs and code into the PostgreSQL plperl language

=head1 SYNOPSIS

    use PostgreSQL::PLPerl::Injector;

    inject_plperl_with_sub($subroutine_ref);

    inject_plperl_with_code($perl_code);

=head1 DESCRIPTION


=head1 OTHER INFORMATION

=head2 Author and Copyright

Tim Bunce L<http://www.tim.bunce.name>

Copyright (c) Tim Bunce, Ireland, 2010. All rights reserved.
You may use and distribute on the same terms as Perl 5.10.1.

With thanks to L<http://www.TigerLead.com> for sponsoring development.

=cut

use strict;
use warnings;
use Exporter;
use Carp;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    inject_plperl_with_sub
    inject_plperl_with_code
);

our $debug = 0;




# vim: ts=8:sw=4:sts=4:et
