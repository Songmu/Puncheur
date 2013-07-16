package MonMonMon::Dispatcher;
use strict;
use warnings;
use utf8;
use PhiloPurple::Dispatcher::Lite;

any '/' => sub {
    my $c = shift;

    $c->render('index.tx');
};

1;
