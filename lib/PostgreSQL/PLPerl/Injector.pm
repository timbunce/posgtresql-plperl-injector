package PostgreSQL::PLPerl::Injector;

=head1 NAME

PostgreSQL::PLPerl::Injector - Inject subs and code into the PostgreSQL plperl language

=head1 SYNOPSIS

    use PostgreSQL::PLPerl::Injector;

    inject_plperl_with_names(@names);

    inject_plperl_with_code($perl_code, $allowed_opcodes, $load_dependencies);

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

You can't fully understand this module or evaluate the risks unless you've also
read and understood the documentation for the L<Safe> module.

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

=head2 inject_plperl_with_names

    inject_plperl_with_names(@names)

For example:

    # import names into the main plperlu namespace
    use MIME::Base64 qw(encode_base64 decode_base64);

    # share the names with the main plperl namespace
    inject_plperl_with_names(qw(decode_base64 decode_base64))

Perl subroutines and variables that exist in a package namespace, i.e., non
not lexicals, can be 'shared' with plperl using L</inject_plperl_with_names>.
Doing so creates an alias with that name inside the isolated plperl namespace
that refers to the corresponding item on the outside.

=head3 Risks of Sharing

Injecting a variable name allows plperl code to access and modify the variable
and, if the value is a reference, access and modify any data it references.

Injecting a subroutine name allows plperl code to call the subroutine, naturally.
I<This means execution control flow can move into code that can perform
unrestricted operations>. B<This is potentially very dangerous> if you don't
completely trust all current and future users who may have permission to use
the plperl language. Therefore you should I<only share subroutines that you
have carefully vetted>.

As an extreeme example of what I<not> to do:

    sub dangerous { my $code = shift; eval $code } # DANGEROUS
    inject_plperl_with_names('dangerous');         # DANGEROUS

Given the above, plperl code would be able to completely escape the
restrictions of the plperl language by calling

    dangerous('... unsafe perl code ...');

Okay, I'm sure that seems pretty obvious and you'd never do that.
Fine, but there are undoubtedly I<many> possible ways to subvert the system
that would be much harder to anticipate.

For example, a subroutine you've shared may call other code that, somewhere
sometime, does a C<require> to load an extra module. Perhaps hostile plperl
code could alter @INC before calling the subroutine in order to cause hostile
code to be loaded instead of the expected code. I've not checked this
possibility, it's simply a plausible example.  Perl caches some values and
references to values internally so it can be hard to evaluate the true risks
without studying the perl source code or trying it yourself. Are you sure
you're smarter than any potential attacker? Do you want to take the risk?

Hopefully I've made it clear that sharing subroutines with plperl is not
something to be done lightly. I<Evaluate the code and the risks in each case.>

=head3 Limitations of Sharing

The plperl language executes code with the package namespace modified
such that a specific non-C<main::> package appears to be C<main::>.
Code compiled outside plperl may not refer to the same packages or package
variables as code compiled inside plperl. This may cause subtle bugs.

=head2 inject_plperl_with_code

    inject_plperl_with_code($perl_code, $allowed_opcodes, $load_dependencies);

This function provides an alternative approach for making external code
available to plperl. Instead of loading code outside of plperl and then sharing
individual subroutines via L</inject_plperl_with_names>, using
L</inject_plperl_with_code> you can load entire modules into plperl.

The plperl language uses L<Safe> to restrict what operations (perl I<opcodes>)
can be compiled. For example, file operations like C<open()> are not allowed.

    inject_plperl_with_code('use Foo qw(bar)', 'caller,tied', 0);

Refer to L</Sort Bug> affecting code loaded inside the compartment.

=head1 NOTES

=head2 Sort Bug

A perl bug affects calls to sort() in plperl code: RT#60374. The $a and $b
variables don't work in C<sort> blocks inside L<Safe> if the perl being used
was compiled with threads enabled. This module enables a partial workaround:

    # workaround http://rt.perl.org/rt3//Public/Bug/Display.html?id=60374
    inject_plperl_with_names(qw(*a *b));

It's partial because it doesn't fix calls to sort() compiled in other packages.

Untested conjecture: it might be possible to extend this workaround on a
package-by-package basis, something like this:

    # make sort work in package Foo
    *Foo::a = *a;
    *Foo::b = *b;
    inject_plperl_with_names(qw(*Foo::a *Foo::b));

If so it might be worth adding a new function: inject_plperl_sort_fix('Foo');

=head1 LIMITATIONS

You can't share %_SHARED between plperl and plperlu languages because the
languages execute in two separate instances of the Perl interpreter.

=head1 AUTHOR

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
use Safe;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    inject_plperl_with_names
    inject_plperl_with_code
);

our $debug = 0;

my %requested_names;
my @requested_code;

sub inject_plperl_with_names {
    my @names = @_;
    # XXX sanity check
    # warn if not a defined sub?
    $requested_names{$_}++ for @names;
}

sub inject_plperl_with_code {
    my ($code, $ops) = @_;
    # XXX sanity check ops
    push @requested_code, [ $code, $ops ];
}


# PostgreSQL 8.x:
# plperl only calls share() (and thus share_from) once during setup
# and after the opmask has been established.
# So we can use share_from() as a useful hook point.

my $orig_share_from = \&Safe::share_from;
do {

    my $hooked_share_from = sub {
        my $safe = shift;

        _inject($safe)
            if $safe->{Root} eq 'PLPerl' # PostgreSQL 8.x
            or $safe->{Root} eq 'PostgreSQL::InServer::safe_container';

        return $safe->$orig_share_from(@_);
    };

    no warnings qw(redefine);
    *Safe::share_from = $hooked_share_from;
};


sub _inject {
    my ($safe) = @_;

    # just once per container
    return if $safe->{__plperl_injector__}++;

    eval {

        # inject subs first, so injected code can call them
        my @names = keys %requested_names;
        warn "Sharing with plperl: @names\n" if @names;
        $safe->$orig_share_from('main', \@names);

        for my $code (@requested_code) {
            warn "Executing in plperl: $code\n";
            _inject_code($safe, @$code);
        }

    };
    warn __PACKAGE__." error: $@" if $@;
}


sub _inject_code {
    my ($safe, $code, $ops) = @_;

}


# vim: ts=8:sw=4:sts=4:et
