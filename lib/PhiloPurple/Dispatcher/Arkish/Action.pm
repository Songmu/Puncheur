package PhiloPurple::Dispatcher::Arkish::Action;
use Mouse;
extends 'Path::AttrRouter::Action';
no Mouse;

sub dispatch {
    my ($self, $c, @args) = @_;
    return if $c->detached;

    $self->controller->ACTION( $self, $c, @args );
}

1;
