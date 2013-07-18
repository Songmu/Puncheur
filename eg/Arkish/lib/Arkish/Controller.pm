package Arkish::Controller;
use strict;
use warnings;
use utf8;

use parent 'PhiloPurple::Dispatcher::Arkish::Controller';

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->res->body('hoge');
}

1;
