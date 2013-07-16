package PLite;
use strict;
use warnings;
use utf8;
use PhiloPurple::Lite;

any '/' => sub {
    my $c = shift;

    $c->render('index.tx');
};

1;

__DATA__
@@ index.tx
<h1>It Works!</h1>
