package PhiloPurple::Dispatcher::Arkish::Context;
use strict;
use warnings;

use Scalar::Util;

our @EXPORT = qw/forward detach execute detach depth stack state detached _arkish_error res response render render_and_detach/;

sub response {
    my ($c, $response) = @_;

    if ($response) {
        $c->{response} = $response;
    }
    elsif (!$c->{response}) {
        $c->{response} = $c->create_response(200)
    }
    $c->{response};
}
{
    no warnings 'once';
    *res = \&response;
}

sub depth {
    scalar @{ shift->stack };
}

sub stack {
    my $c = shift;
    $c->{stack} ||= [];
}

sub _arkish_error {
    my $c = shift;
    $c->{_arkish_error} ||= [];
}

sub state {
    my $c = shift;
    if (@_) {
        $c->{state} = $_[0];
    }
    elsif (!exists $c->{state}) {
        $c->{state} = 0;
    }
    $c->{state};
}

sub detached {
    my $c = shift;
    if (@_) {
        $c->{detached} = $_[0];
    }
    elsif (!exists $c->{detached}) {
        $c->{detached} = 0;
    }
    $c->{detached};
}

our $DETACH = 'ARKISH_DETACH';
sub execute {
    my ($c, $obj, $method, @args) = @_;
    my $class = ref $obj;

    $c->state(0);
    push @{ $c->stack }, {
        obj       => $obj,
        method    => $method,
        args      => \@args,
        as_string => "${class}->${method}"
    };

    local $@;
    my $error;
    eval {
        $c->execute_action($obj, $method, @args);
    };
    $error = $@ if $@;
    pop @{ $c->stack };

    if ($error) {
        if ($error =~ /^${DETACH} at /) {
            die $DETACH if ($c->depth >= 1);
            $c->detached(1);
        }
        else {
            push @{ $c->_arkish_error }, $error;
            $c->state(0);
        }
    }
    $c->state;
}

sub execute_action {
    my ($c, $obj, $method, @args) = @_;

    my $state = $obj->$method($c, @args);
    $c->state( $state // undef );
}

sub forward {
    my ($c, $target, @args) = @_;
    return 0 unless $target;

    unless (@args) {
        @args = @{ $c->req->captures } ? @{ $c->req->captures } : @{ $c->req->args };
    }

    if (Scalar::Util::blessed($target)) {
        if ($target->isa('PhiloPurple::Dispatcher::Arkish::Action')) {
            $target->dispatch($c, @args);
            return $c->state;
        }
        elsif ($target->can('process')) {
            $c->execute($target, 'process', @args);
            return $c->state;
        }
    }
    else {
        if ($target =~ m!^/.+!) {
            my ($namespace, $name) = $target =~ m!^(.*/)([^/]+)$!;
            $namespace =~ s!(^/|/$)!!g;
            if (my $action = $c->get_action($name, $namespace || '')) {
                $action->dispatch($c, @args);
                return $c->state;
            }
        }
        else {
            my $last = $c->stack->[-1];
            if ($last
                 and $last->{obj}->isa('PhiloPurple::Dispatcher::Arkish::Controller')
                 and my $action = $c->get_action($target, $last->{obj}->namespace)) {

                $action->dispatch($c, @args);
                return $c->state;
            }
        }
    }

    my $error = qq/Couldn't forward to $target, Invalid action or component/;
    push @{ $c->_arkish_error }, $error;

    return 0;
}

sub detach {
    shift->forward(@_);
    die $DETACH;
}

sub render {
    my $c = shift;

    my $res = $c->PhiloPurple::render(@_);
    $c->res($res);
}

sub render_and_detach {
    my $c = shift;

    $c->render(@_);
    $c->detach;
}

1;
