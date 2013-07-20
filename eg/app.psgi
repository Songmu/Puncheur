use strict;
use warnings;
use utf8;
use lib 'lib';
use PhiloPurple;

my $app = PhiloPurple->new(
    view         => 'MT',
    template_dir => 'eg/tmpl',
);

$app->to_psgi;
