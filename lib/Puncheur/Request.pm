package Puncheur::Request;
use strict;
use warnings;

use parent 'Plack::Request';
use Carp ();
use Encode;
use Hash::MultiValue;
use URL::Encode;
use URI::QueryParam;

sub uri {
    my $self = shift;

    $self->{uri} ||= $self->SUPER::uri;
    $self->{uri}->clone; # avoid destructive opearation
}

sub base {
    my $self = shift;

    $self->{base} ||= $self->SUPER::base;
    $self->{base}->clone; # avoid destructive operation
}

sub body_parameters {
    my ($self) = @_;
    $self->{body_parameters} ||= $self->_decode_parameters($self->SUPER::body_parameters);
}

sub query_parameters {
    my ($self) = @_;
    $self->{query_parameters} ||= $self->_decode_parameters($self->query_parameters_raw);
}

sub _decode_parameters {
    my ($self, $stuff) = @_;

    my @flatten = $stuff->flatten;
    my @decoded;
    while ( my ($k, $v) = splice @flatten, 0, 2 ) {
        push @decoded, Encode::decode_utf8($k), Encode::decode_utf8($v);
    }
    return Hash::MultiValue->new(@decoded);
}
sub parameters {
    my $self = shift;
    $self->{'request.merged'} ||= do {
        my $query = $self->query_parameters;
        my $body  = $self->body_parameters;
        Hash::MultiValue->new( $query->flatten, $body->flatten );
    };
}

sub body_parameters_raw {
    shift->SUPER::body_parameters;
}

sub query_parameters_raw {
    my $self = shift;
    my $env  = $self->{env};
    $env->{'plack.request.query'} ||= Hash::MultiValue->new(@{URL::Encode::url_params_flat($env->{'QUERY_STRING'})});
}

sub parameters_raw {
    my $self = shift;
    $self->{env}{'plack.request.merged'} ||= do {
        my $query = $self->query_parameters_raw;
        my $body  = $self->SUPER::body_parameters;
        Hash::MultiValue->new( $query->flatten, $body->flatten );
    };
}

sub param_raw {
    my $self = shift;

    return keys %{ $self->parameters_raw } if @_ == 0;

    my $key = shift;
    return $self->parameters_raw->{$key} unless wantarray;
    return $self->parameters_raw->get_all($key);
}

sub uri_with {
    my( $self, $query, $behavior) = @_;
    Carp::carp( 'No arguments passed to uri_with()' ) unless $query;

    my $append = ref $behavior eq 'HASH' && $behavior->{mode} && $behavior->{mode} eq 'append';
    my @query = ref $query eq 'HASH' ? %$query : @$query;
    @query = map { $_ && encodde_utf8($_) } @query;

    my $params = do {
        my %params = %{ $self->uri->query_form_hash };

        while (my ($key, $val) = splice @query, 0, 2) {
            if ( defined $val ) {
                if ( $append && exists $params{$key} ) {
                    $params{$key} = [
                        (ref $params{$key} eq 'ARRAY' ? @{ $params{$key} } : $params{$key}),
                        (ref $val eq 'ARRAY'          ? @$val              : $val),
                    ];
                }
                else {
                    $params{$key} = $val;
                }
            }
            else {
                # If the param wasn't defined then we delete it.
                delete( $params{$key} );
            }
        }
        \%params;
    };

    my $uri = $self->uri;
    $uri->query_form($params);

    return $uri;
}

sub capture_params {
    my ($self, @params) = @_;
    (map {($_ => $self->parameters->get($_))} @params);
}

1;
