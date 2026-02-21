BEGIN {
  chdir 't' if -d 't';
  require './test.pl';
  set_up_inc('../lib');
}
use feature 'try';
use strict;

# basic test the parsing in all the covered cases
my $s;
for my $code (
  '$s?->$*',
  # array operations
  '$s?->[0]', '$s?->@*', '$s?->$#*',
  # array slices
  '$s?->@[0,1]', '$s?->%[0,1]',
  # hash operations
  '$s?->{0}', '$s?->%*',
  # hash slices
  '$s?->@{qw(a b)}', '$s?->%{qw(a b)}',
  # method calls - tested separately below due to eval + optchain method interaction
  # '$s?->foo', '$s?->foo(1, 2)',
  # subref operations
  '$s?->()', '$s?->(1, 2)', '$s?->&*',
  # globref operations
  '$s?->**', '$s?->*{NAME}',
  # quick lvalue test
  #  '$s?->[0] = 1'
) {
  is eval $code, undef, "`$code` runs undef as expected";
  is $@, '', "`$code` compiles!"
}

# --- array element operations ---
my $undef;

$undef?->[0];
is $undef, undef, 'aelem: no autovivification';

my $ary = [ 1 ];
is $ary?->[0], 1, 'aelem: defined access';

my $did_we_die;
try {
  $undef?->[die "not reached"]
} catch ($err) {
  $did_we_die = $err;
}
is $did_we_die, undef, 'aelem: do not run ANY of the RHS if undef';
$did_we_die = undef;

try {
  $undef?->[0][1];
} catch ($err) {
  $did_we_die = $err;
}
is $did_we_die, undef, 'aelem: short-circuit even subscripted access';
$did_we_die = undef;

# --- hash element operations ---
my $href = { a => 1, b => 2 };
is $href?->{a}, 1, 'helem: defined access';
is $undef?->{a}, undef, 'helem: undef access';

$undef?->{a};
is $undef, undef, 'helem: no autovivification';

# --- scalar deref ---
my $sref = \42;
is $sref?->$*, 42, 'scalar deref: defined access';
is $undef?->$*, undef, 'scalar deref: undef access';

# --- array deref ---
my @empty_ary = $undef?->@*;
is $#empty_ary, -1, 'array deref: undef gives empty list, not undef';

my $aref = [10, 20, 30];
my @full_ary = $aref?->@*;
is join(",", @full_ary), "10,20,30", 'array deref: defined access';

# --- hash deref ---
my @empty_hash = $undef?->%*;
is scalar @empty_hash, 0, 'hash deref: undef gives empty list';

my @full_hash = $href?->%*;
is scalar @full_hash, 4, 'hash deref: defined access returns kv pairs';

# --- arylen ---
is $aref?->$#*, 2, 'arylen: defined access';
is $undef?->$#*, undef, 'arylen: undef access';

# --- coderef calls ---
my $code_noargs = sub { 42 };
my $code_args   = sub { $_[0] + $_[1] };

is $code_noargs?->(), 42, 'coderef: call with no args';
is $code_args?->(3, 4), 7, 'coderef: call with args';
is $undef?->(), undef, 'coderef: undef call returns undef';
is $undef?->(1, 2), undef, 'coderef: undef call with args returns undef';

# --- array slices ---
{
  my $a = [10, 20, 30, 40, 50];

  my @slice = $a?->@[1, 3];
  is join(",", @slice), "20,40", 'aslice: defined access';

  my @undef_slice = $undef?->@[0, 1];
  is scalar @undef_slice, 0, 'aslice: undef gives empty list';

  $undef?->@[0, 1];
  is $undef, undef, 'aslice: no autovivification';

  my $counter = 0;
  $undef?->@[$counter++, $counter++];
  is $counter, 0, 'aslice: indices not evaluated on undef';
}

# --- hash slices ---
{
  my $h = { a => 1, b => 2, c => 3 };

  my @slice = $h?->@{qw(a c)};
  is join(",", sort @slice), "1,3", 'hslice: defined access';

  my @undef_slice = $undef?->@{qw(a b)};
  is scalar @undef_slice, 0, 'hslice: undef gives empty list';

  $undef?->@{qw(a)};
  is $undef, undef, 'hslice: no autovivification';

  my $counter = 0;
  $undef?->@{$counter++};
  is $counter, 0, 'hslice: keys not evaluated on undef';
}

# --- kv array slices ---
{
  my $a = [10, 20, 30];

  my @kv = $a?->%[0, 2];
  is join(",", @kv), "0,10,2,30", 'kvaslice: defined access';

  my @undef_kv = $undef?->%[0, 1];
  is scalar @undef_kv, 0, 'kvaslice: undef gives empty list';
}

# --- kv hash slices ---
{
  my $h = { a => 1, c => 3 };

  my @kv = $h?->%{qw(a c)};
  is join(",", sort @kv), "1,3,a,c", 'kvhslice: defined access';

  my @undef_kv = $undef?->%{qw(a b)};
  is scalar @undef_kv, 0, 'kvhslice: undef gives empty list';
}

# --- chained access after optchain ---
{
  my $nested = [[1, 2], [3, 4]];
  is $nested?->[1][0], 3, 'chained: subscript after optchain element';

  my $deep = { a => { b => 42 } };
  is $deep?->{a}{b}, 42, 'chained: hash subscript after optchain element';
}

# --- nested optchains ---
{
  is $undef?->[$undef?->[0]], undef, 'nested: outer undef skips everything';

  # nested optchain in index expression
  my $outer = [10, 20, 30, 40, 50, 60];
  my $inner = [5];
  is $outer?->[$inner?->[0]], 60, 'nested: inner optchain as index';
  is $outer?->[$undef?->[0]], 10, 'nested: inner undef gives $outer->[0]';
}

# --- method calls ---
{
  package OptchainTestClass;
  sub new { bless {x => 42}, shift }
  sub x { $_[0]->{x} }
  sub add { $_[0]->{x} + $_[1] }

  package main;
  my $obj = OptchainTestClass->new;

  is $obj?->x, 42, 'method: no args defined';
  is $obj?->x(), 42, 'method: no args with parens defined';
  is $obj?->add(8), 50, 'method: with args defined';

  is $undef?->x, undef, 'method: no args undef';
  is $undef?->x(), undef, 'method: no args with parens undef';
  is $undef?->add(8), undef, 'method: with args undef';

  # side effects in args should not run on undef
  my $counter = 0;
  $undef?->add($counter++);
  is $counter, 0, 'method: args not evaluated on undef';

  # no autovivification
  $undef?->x;
  is $undef, undef, 'method: no autovivification';
}
# --- glob member deref ---
{
  my $gref = \*STDOUT;
  is ref($gref?->*{IO}), 'IO::File', 'gelem: defined access';

  my $undef;
  is $undef?->*{IO}, undef, 'gelem: undef access';

  $undef?->*{IO};
  is $undef, undef, 'gelem: no autovivification';
}

# --- eval string ---
{
  my $x;
  eval q{ $x?->foo };
  is $@, '', 'eval string: method no parens compiles';

  eval q{ $x?->foo() };
  is $@, '', 'eval string: method with parens compiles';

  eval q{ $x?->foo(1,2) };
  is $@, '', 'eval string: method with args compiles';

  # multiple evals with same method name (was use-after-free)
  eval q{ $x?->bar() };
  eval q{ $x?->bar() };
  is $@, '', 'eval string: repeated method name no crash';

  # non-method optchain in eval
  eval q{ $x?->[0] };
  is $@, '', 'eval string: aelem compiles';

  eval q{ $x?->{a} };
  is $@, '', 'eval string: helem compiles';
}

# --- interpolation ---
{
  my $empty = '';
  is "$empty?->[0]", "?->[0]", 'interpolation: optchain treated as literal';
}

done_testing();
