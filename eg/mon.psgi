use strict;
use warnings;
use utf8;
use lib 'lib', 'eg/MonMonMon/lib';
use MonMonMon;

my $app = MonMonMon->bootstrap;
$app->to_psgi;
