#!/usr/bin/env perl
use 5.010;
use warnings;
use utf8;

use PhiloPurple::Runner;

PhiloPurple::Runner->new('PLite', {
    server => 'Starlet',
    port   => 1988,
})->run;
