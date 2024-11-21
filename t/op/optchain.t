use feature 'try';
use strict;

BEGIN {
  chdir 't' if -d 't';
  require './test.pl';
  set_up_inc('../lib');
}


# basic test the parsing in all the covered cases
my $s;
for my $code (
  '$s?->$*',
  # array operations
  '$s?->[0]', '$s?->@*',# TODO - '$s?->@[1..10]', 
  # hash operations
  '$s?->{0}', '$s?->%*', # TODO - '$s?->%{1..10}', 
  # method calls
  #'$s?->method()', '$s?->method(1, 2)',
  # subref operations
  '$s?->()', '$s?->(1, 2)', ) {
  eval $code;
  is $@, '', "`$code` has no errors!"
}

# array operations
my $undef;

$undef?->[0];
is $undef, undef, 'no autovivification';

my $ary = [ 1 ];
is $ary?->[0], 1, 'arrayref access';

my $did_we_die;
try {
  $undef?->[die "not reached"]
} catch ($err) { 
  $did_we_die = $err;
}
is $did_we_die, undef, 'do not run ANY of the RHS if undef';

my $empty = '';
is "$empty?->[0]", "?->[0]", 'optchain ignored during interpolation';

done_testing();
