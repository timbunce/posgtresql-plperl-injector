package PostgreSQL::PLPerl::Injector;

=head1 NAME

PostgreSQL::PLPerl::Injector - Inject subs and code into the PostgreSQL plperl language

=head1 SYNOPSIS

    use PostgreSQL::PLPerl::Injector;

    inject_plperl_with_sub($subroutine_name);

    inject_plperl_with_code($perl_code, $allowed_opcodes, $load_dependencies);
    inject_plperl_with_code('use Foo qw(bar)', 'caller,tied'', 0);

=head1 DESCRIPTION

The PostgreSQL C<plperl> language enables functions (stored procedures) to be
defined using Perl and executed inside the PostgreSQL server. PostgreSQL uses
the L<Safe> module to restrict the operations that can be performed in C<plperl>.

PostgreSQL doesn't provide any mechanism for C<plperl> code to access external
code, like CPAN modules. This greatly limits the utility of the C<plperl> language.

This module provides two ways to inject code into the PostgreSQL plperl Safe
compartment in which C<plperl> code is executed:

B<*> by sharing (importing) individual subroutines into the compartment.

B<*> by executing code, like "C<use Foo qw(...);>", inside the compartment
with the restrictions temporarily relaxed.

=head1 WARNING

This module 'monkey patches' the code of the L<Safe> module being used within
PostgreSQL. This naturally carries at least some theoretical risk. Do not use
this module unless you understand the risks.

=head1 ENABLING

In order to use this module you need to arrange for it to be loaded when
PostgreSQL initializes a Perl interpreter.

=head2 PostgreSQL 8.x

XXX talk about loading via PERL5OPT env var
Note that PERL5OPT env var code should unset PERL5OPT to avoid problems with
nested perl invocation (by pg_ctl or plperlu code etc.).

=head2 PostgreSQL 9.0

For PostgreSQL 9.0 you can still use the C<PERL5OPT> method described above.
Alternatively you can use the C<plperl.on_init> configuration variable in the
F<postgres.conf> file.

=head1 USAGE

=head2 Sharing Subroutines With The Compartment

XXX

=head2 Loading Code Into The Compartment

XXX

=head1 OTHER INFORMATION

=head2 Author and Copyright

Tim Bunce L<http://www.tim.bunce.name>

Copyright (c) Tim Bunce, Ireland, 2010. All rights reserved.
You may use and distribute on the same terms as Perl 5.10.1.

With thanks to L<http://www.TigerLead.com> for sponsoring development.

=head1 REMINDER

You did read and understand the L</WARNING> didn't you?

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
