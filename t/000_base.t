use strict;
use warnings;
use utf8;
use Test::More;

use PhiloPurple;
pass 'use PhiloPurple ok';

my $app = PhiloPurple->new;
ok $app;
isa_ok $app, 'PhiloPurple';

done_testing;
