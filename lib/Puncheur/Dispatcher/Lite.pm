package Puncheur::Dispatcher::Lite;
use strict;
use warnings;
use Router::Simple 0.14;
use Router::Simple::Sinatraish;

sub import {
    my $class = shift;
    my $caller = caller(0);

    Router::Simple::Sinatraish->export_to_level(1);
    my $router = $caller->router;

    no strict 'refs';
    *{"$caller\::dispatch"} = sub {
        my ($klass, $c) = @_;
        $c = $klass unless $c;

        if (my $p = $router->match($c->request->env)) {
            return $p->{code}->($c, $p);
        } else {
            if ($router->method_not_allowed) {
                return $c->res_405();
            } else {
                return $c->res_404();
            }
        }
    };
}

1;
