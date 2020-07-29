# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :Sealed subroutine attributes: use with care!
#
# Author: Joe Schaefer <joe@sunstarsys.com>

package sealed;

use strict;
use warnings;

use B::Generate ();
use B::Deparse  ();

our $VERSION       = v1.0.2;
our $DEBUG;

my %valid_attrs    = (sealed => 1);
my $p_obj          = B::svref_2object(sub {&tweak});
my B::PADOP $padop = $p_obj->START->next->next;

sub tweak ($\@\@\@) {
  my ($op, $lexical_names, $pads, $op_stack) = @_;
  my $tweaked = 0;

  if ($op->next->name eq "padsv") {
    $op         = $op->next;
    my $type    = $$lexical_names[$op->targ]->TYPE;

    if ($type->isa("B::HV")) {
      my $class = $type->NAME;

      while ($op->next->name ne "entersub") {

	if ($op->next->name eq "pushmark") {
	  # we need to process this arg stack recursively
	  splice @_, 0, 1, $op->next;
	  ($op, my $t)         = &tweak;
	  $tweaked            += $t;
	}

	elsif ($op->next->name eq "method_named") {
	  my B::METHOP $methop = $op->next;
	  my $targ             = $methop->targ;

	  # a little prayer
	  my ($method_name, $idx);
	  $method_name         = $$pads[$idx++][$targ] while not defined $method_name;
	  warn __PACKAGE__, ": compiling $class->$method_name lookup.\n"
	    if $DEBUG;

	  my $method           = $class->can($method_name)
	    or die __PACKAGE__ . ": invalid lookup: $class->$method_name - did you forget to 'use $class' first?";
	  $$_[$targ]           = $method for @$pads; # bulletproof, blanket bludgeon

	  # replace $methop (this bless below is needed because B::Generate is too old)
	  my B::PADOP $gv      = bless $padop->new($padop->name, $padop->flags), ref $padop;
	  $gv->padix($targ);
	  $gv->next($methop->next);
	  $gv->sibling($methop->sibling);
	  $op->next($gv);

	  $tweaked++;
	}
	$op = $op->next;
      }

      $op = $op->next;
    }

  }

  push @$op_stack, $op->next;
  return ($op, $tweaked);
}

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep $valid_attrs{+lc}, @attrs) {

    my $cv_obj             = B::svref_2object($rv);
    my @op_stack           = ($cv_obj->START);
    my ($pad_names, @p)    = $cv_obj->PADLIST->ARRAY;
    my @pads               = map $_->object_2svref, @p;
    my @lexical_names      = $pad_names->ARRAY;
    my %processed_op;
    my $tweaked;

    while (my $op = shift @op_stack) {
      ref $op and $$op and not $processed_op{$$op}++
        or next;

      $op->dump if defined $DEBUG and $DEBUG eq 'dump';

      if ($op->name eq "pushmark") {
	$tweaked += tweak($op, @lexical_names, @pads, @op_stack);
      }
      elsif ($op->can("pmreplroot")) {
        push @op_stack, $op->pmreplroot, $op->next;
      }
      elsif ($op->can("first")) {
	for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	  push @op_stack, $kid;
	}
	unshift @op_stack, $op->next;
      }
      else {
        unshift @op_stack, $op->next;
      }

    }

    if (defined $DEBUG and $DEBUG eq "deparse" and $tweaked) {
      warn B::Deparse->new->coderef2text($rv), "\n";
    }

  }

  return grep !$valid_attrs{+lc}, @attrs;
}

sub import {
  $DEBUG = $_[1];
}

1;

__END__

=head1 sealed

Subroutine attribute for compile-time method lookups on its typed lexicals.

=over 4

=item Sample Usage

    use Apache2::RequestRec;
    use base 'sealed';

    sub handler :Sealed {
      my Apache2::RequestRec $r = shift;
      $r->content_type("text/html"); # compile-time method lookup.
    ...

=item C<import()> Options

    use sealed 'debug';   # warns about 'method_named' op tweaks
    use sealed 'deparse'; # additionally warns with the B::Deparse output
    use sealed 'dump';    # warns with the $op->dump during the tree walk
    use sealed;           # disables all warnings

=item BUGS

You may need to simplify your named method call argument stack,
because this op-tree walker isn't as robust as it needs to be.
For example, any "branching" done in the target method's argument
stack, eg by using the '?:' ternary operator, will break this logic.

=item CAVEATS

Don't use this if you are writing a reusable OO module (on CPAN, say).
This module targets end-applications: virtual method lookups and
duck typing are core elements of any dynamic language's OO feature
design, and Perl is no different.  Look into XS if you want peak
performance in reusable OO methods you wish to provide.

=item See Also

L<https://www.sunstarsys.com/essays/perl7-sealed-lexicals>

=back
