package PhiloPurple::Dispatcher::Arkish::Controller;
use Mouse;
extends 'Path::AttrRouter::Controller';
no Mouse;

sub ACTION {
    my ($self, $action, $context, @args) = @_;
    $context->execute( $self, $action->name, @args );
}

1;
