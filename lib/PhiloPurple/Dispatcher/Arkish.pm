package PhiloPurple::Dispatcher::Arkish;
use strict;
use warnings;
use utf8;

use Path::AttrRouter;

sub new {
    my ($class, $c) = @_;

    my $caller = caller();
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

        $self->dispatch_private_action($c, 'end');
    }
    else {
        $c->res_404;
    }
}

sub dispatch_private_action {
    my ($self, $c, $name) = @_;

    my $action = ($self->router->get_actions($name, $self->req->action->namespace))[-1];
    return 1 unless ($action and $action->attributes->{Private});

    $action->dispatch($c);

    !@{ $self->error };
}


sub dispatch_auto_action {
    my ($self, $c) = shift;

    for my $auto ($self->router->get_actions('auto', $self->req->action->namespace)) {
        next unless $auto->attributes->{Private};
        $auto->dispatch($self);
        return 0 unless $self->state;
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

{
    no strict 'refs';
    *{__PACKAGE__."::$_"} = sub {
        shift->match->$_(@_);
    }
    for qw/action args captures/
}

1;
