package PhiloPurple::Dispatcher::Arkish;
use strict;
use warnings;

use Path::AttrRouter;

sub new {
    my ($class, $c) = @_;

    my $caller = $c->app_name;
    $caller->load_plugin('+PhiloPurple::Dispatcher::Arkish::Context');

    my $router = Path::AttrRouter->new(
        search_path  => "$caller\::Controller",
        action_class => 'PhiloPurple::Dispatcher::Arkish::Action',
    );
    bless {router => $router}, $class;
}

sub router { shift->{router} }

sub dispatch {
    my ($self, $c) = @_;

    my $req = $c->req;
    my $match = $self->router->match($req->path);
    $req->match($match);
    if ($match) {
        $self->dispatch_private_action($c, 'begin')
            and $self->dispatch_auto_action($c)
                and $match->dispatch($c);

        $c->detached(0);
        $self->dispatch_private_action($c, 'end');

        $c->res;
    }
    else {
        $c->res_404;
    }
}

sub dispatch_private_action {
    my ($self, $c, $name) = @_;

    my $action = ($self->router->get_actions($name, $c->req->action->namespace))[-1];
    return 1 unless ($action and $action->attributes->{Private});

    $action->dispatch($c);

    !@{ $c->_arkish_error };
}

sub dispatch_auto_action {
    my ($self, $c) = @_;

    for my $auto ($self->router->get_actions('auto', $c->req->action->namespace)) {
        next unless $auto->attributes->{Private};
        $auto->dispatch($c);
        return 0 unless $c->state;
    }
    1;
}


package # extends
    PhiloPurple::Request;

sub match {
    my ($self, $match) = @_;

    $self->{match} = $match if $match;
    $self->{match};
}

for my $method (qw/action args captures/) {
    no strict 'refs';
    *{__PACKAGE__."::$method"} = sub {
        shift->match->$method(@_);
    };
}

1;
