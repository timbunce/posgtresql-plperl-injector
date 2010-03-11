package PostgreSQL::PLPerl::Injector;

=head1 NAME

PostgreSQL::PLPerl::Injector - Inject subroutines into the PostgreSQL plperl language

=head1 SYNOPSIS

    use PostgreSQL::PLPerl::Injector;

    inject_plperl_with_names(@names);

    inject_plperl_with_names_from($module => @names);

=head1 DESCRIPTION

The PostgreSQL C<plperl> language enables functions (stored procedures) to be
defined using Perl and executed inside the PostgreSQL server. PostgreSQL uses
the L<Safe> module to restrict the operations that can be performed in C<plperl>.

PostgreSQL doesn't provide any mechanism for C<plperl> code to access external
code, like CPAN modules. This greatly limits the utility of the C<plperl> language.

This module lets you 'inject' subroutine names into the L<Safe> compartment in
which C<plperl> code is executed. You can then call those subroutines in your
plperl code.

=head1 WARNING

This module 'monkey patches' the code of the L<Safe> module being used within
PostgreSQL. This naturally carries at least some theoretical risk. Do not use
this module unless you understand the risks.

You can't fully understand this module or begin to evaluate the risks unless
you've also read and understood the documentation for the L<Safe> module.

By calling a subroutine name injected into plperl, control flow 'escapes'
from the L<Safe> container in which plperl code normally executes.
The implications of this are subtle and hard to predict - even by those very
familar with the internal workings of perl and Safe.

If you don't trust your users you should not use this module.

=head1 ENABLING

In order to use this module you need to arrange for it to be loaded when
PostgreSQL initializes a Perl interpreter.

Create a F<plperlinit.pl> file in the same directory as your
F<postgres.conf> file, if it doesn't exist already.

In the F<plperlinit.pl> file write the code to load this module, plus any
others you want to load and share subroutines from. (After reading and
considering the risks outlined in L</WARNINGS>.)

=head2 PostgreSQL 8.x

Set the C<PERL5OPT> before starting postgres, to something like this:

    PERL5OPT='-e "require q{plperlinit.pl}"'

The code in the F<plperlinit.pl> should also include C<delete $ENV{PERL5OPT};>
to avoid any problems with nested invocation of perl, perhaps via a C<plperlu>
function.

=head2 PostgreSQL 9.0

For PostgreSQL 9.0 you can still use the C<PERL5OPT> method described above.
Alternatively, and preferably, you can use the C<plperl.on_init> configuration
variable in the F<postgres.conf> file.

    plperl.on_init='require q{plperlinit.pl};'

=head1 SHARING SUBROUTINES

=head2 inject_plperl_with_names

    inject_plperl_with_names(@names)

For example:

    # import names into the main plperlu namespace
    use MIME::Base64 qw(encode_base64 decode_base64);

    # share the names with the main plperl namespace
    inject_plperl_with_names(qw(encode_base64 decode_base64))

Perl subroutines and variables that exist in a package namespace, i.e., non
not lexicals, can be 'shared' with plperl using L</inject_plperl_with_names>.
Doing so creates an alias with that name inside the isolated plperl namespace
that refers to the corresponding item on the outside.

=head2 inject_plperl_with_names_from

    inject_plperl_with_names_from($module => @names)

For example:

    inject_plperl_with_names_from(MIME::Base64 => qw(encode_base64 decode_base64))

This is a convenience function that loads the specified module, imports the
names into the callers namespace (for the convenience of the plperlu language)
and then calls L</inject_plperl_with_names> with the same list of names.

=head2 Risks of Sharing

Injecting a variable name allows plperl code to access and modify the variable
and, if the value is a reference, access and modify any data it references.

Injecting a subroutine name allows plperl code to call the subroutine, naturally.
I<This means execution control flow can move into code that can perform
unrestricted operations>. B<This is potentially very dangerous> if you don't
completely trust all current and future users who may have permission to use
the plperl language. Therefore you should I<only share subroutines that you
have carefully vetted>.

As an extreme example of what I<not> to do:

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
possibility, it's simply a plausible example.

Perl caches some values and references to values internally so it can be hard
to evaluate the true risks without studying the perl source code or trying it
yourself. Are you sure you're smarter than any potential attacker? Do you want
to take the risk?

Hopefully I've made it clear that sharing subroutines with plperl is not
something to be done lightly. I<Evaluate the code and the risks in each case.>

=head2 Limitations of Sharing

The plperl language executes code with the package namespace modified
such that a specific non-C<main::> package appears to be C<main::>.
Code compiled outside plperl may not refer to the same packages or package
variables as code compiled inside plperl. This may cause subtle bugs.

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

A better fix is to compile postgres to use a perl that was configured with
multiplicity but not threads (Configure -Uusethreads -Dusemultiplicity).
That'll not only fix the sort bug but also give you a significant boost in the
performance of your perl code.

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
    inject_plperl_with_names_from
);

our $debug = 0;

my @inject_names_action;


sub inject_plperl_with_names_from {
    my ($module, @names) = @_;

    croak "No names to inject specified" unless @names;

    push @inject_names_action, sub {
        _inject_names_from(shift, $module, @names);
    };
}


sub inject_plperl_with_names {
    inject_plperl_with_names_from(undef, @_);
}


sub _warn {
    print STDERR "@_\n";
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
            if $safe->{Root} eq 'PLPerl'            # PostgreSQL 8.x
            or $safe->{Root} =~ /^PostgreSQL::InServer::safe/; # 9.0

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

        # inject subs before code, so injected code can call them
        $_->($safe) for @inject_names_action;

        # inject modules
        #for my $module_args (@requested_module) {
        #    my ($module, $imports, $ops) = @$module_args;
        #    _inject_module($safe, $module, $imports, $ops);
        #}

        # inject code
        #for my $code_args (@requested_code) {
        #   my ($code, $ops, $allow_use) = @$code_args;
        #   _inject_code($safe, $code, $ops, $allow_use);
        #}

    };
    die __PACKAGE__." error: $@\n" if $@;
}


sub _inject_names_from {
    my ($safe, $module, @names) = @_;
    my $package = 'main';

    if ($module) {
        my $names = join ", ", map { "'$_'" } @names; # XXX
        my $load = "use $module ($names)";
        _warn "Executing $load";
        eval "package $package; $load";
        die "Error executing $load: $@" if $@;
    }

    _warn "Sharing with plperl: @names" if @names;
    $safe->$orig_share_from($package, \@names);
}



=for comment

This code is incomplete and disabled.
It's difficult to implement in a reasonably secure manner.

=head2 inject_plperl_with_code

    inject_plperl_with_code($perl_code, $allowed_opcodes, $load_dependencies);

This function provides an alternative approach for making external code
available to plperl. Instead of loading code outside of plperl and then sharing
individual subroutines via L</inject_plperl_with_names>, using
L</inject_plperl_with_code> you can load entire modules into plperl
or just execute arbitrary fragments of perl code:

    inject_plperl_with_code('sub foo { ... }');

=head3 Opcodes

The plperl language uses L<Safe> to restrict what operations (perl I<opcodes>)
can be compiled. For example, some introspection operators like C<caller()> and
all file operations like C<open()> are not allowed. C<inject_plperl_with_code()>
honours those restrictions by default.

In order to execute $perl_code it's likely that you'll need to relax the
restrictions to allow specific opcodes (or named groups of opcodes called
optags). You can do that by listing them in $allowed_opcodes, separated by
commas. Remember that I<any opcodes you allow create a potential risk> if
hostile plperl could execute the subs that use those opcodes.

but allows you to relax the them 

    inject_plperl_with_code(
        q{ use MIME::Base64 qw(encode_base64 decode_base64) },
        'require,caller,tied',
        allow_nested_load => 1
    );


    # For old perls we add entereval if entertry is listed
    # due to http://rt.perl.org/rt3/Ticket/Display.html?id=70970
    # Testing with a recent perl (>=5.11.4) ensures this doesn't
    # allow any use of actual entereval (eval "...") opcodes.

=head3 Nested use/require

XXX

=head3 Other issues

Refer to L</Sort Bug> affecting code loaded inside the compartment.


my @requested_module;
sub inject_plperl_with_module {
    my ($module, $imports, $ops) = @_;
    # XXX sanity check
    push @requested_module, [ $module, $imports, $ops ];
}

my @requested_code;
sub inject_plperl_with_code {
    my ($code, $ops) = @_;
    # XXX sanity check ops
    push @requested_code, [ $code, $ops ];
}


sub _inject_module {
    my ($safe, $module, $imports, $ops) = @_;

    $ops .= ',require';

    require DynaLoader;
    require XSLoader;
    my $xsl_entry = 'XSLoader::load';

    # share dynaloader and xsloader
    # load the module
    # unshare them
    $safe->share_from('main', [ $xsl_entry ]);

    $safe->reval(q{ $INC{'XSLoader.pm'} = 'injected' });

    my $use = sprintf "use %s %s", $module,
        ($imports && @$imports) ? "qw(@$imports)" : "";
    _warn "inject module: $use";
    eval { _inject_code($safe, $use, $ops) };
    die $@ if $@;

    *{ $safe->varglob($xsl_entry) } = sub {
        die "$xsl_entry not available within plperl";
    };
}


sub _inject_code {
    my ($safe, $code, $ops, $allow_use) = @_;
    $ops ||= '';

    # For old perls we add entereval if entertry is listed
    # due to http://rt.perl.org/rt3/Ticket/Display.html?id=70970
    # Testing with a recent perl (>=5.11.4) ensures this doesn't
    # allow any use of actual entereval (eval "...") opcodes.
    $ops = "entereval,$ops"
        if $] < 5.011004 and $ops =~ /\bentertry\b/;

    _warn(sprintf "Executing in plperl: %s%s%s",
        $code,
        $ops ? ". Extra ops '$ops'" : "",
        $allow_use ? '. Nested use allowed' : "");

    # XXX disallow use unless $allow_use

    my $mask = $safe->mask;

    # relax, eval, restrict, propagate
    $safe->permit(split /\s*,\s*/, $ops) if $ops;

    my $ok = $safe->reval("$code; 1");
    $safe->mask($mask);
    if (not $ok) {
        chomp $@;
        $@ =~ s/\.$//;
        die "$@ (while executing $code)\n";
    }
    _warn "Done executing in plperl.\n";
}
=cut

# vim: ts=8:sw=4:sts=4:et
