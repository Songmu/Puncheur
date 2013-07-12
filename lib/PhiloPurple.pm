package PhiloPurple;
use 5.010;;
use strict;
use warnings;

our $VERSION = "0.01";

use Encode;
use URL::Encode;
use Plack::Session;
use PhiloPurple::Request;
use PhiloPurple::Response;
use PhiloPurple::Trigger qw/add_trigger call_trigger get_trigger_code/;
use Scalar::Util ();

# -------------------------------------------------------------------------
# Hook points:
# You can override these methods.
sub create_request  { PhiloPurple::Request->new($_[1], $_[0]) }
sub create_response { shift; PhiloPurple::Response->new(@_) }
sub create_view     { die "This is abstract method: create_view" }
sub dispatch        { die "This is abstract method: dispatch"    }

sub html_content_type { 'text/html; charset=UTF-8' }
sub encoding { state $enc = Encode::find_encoding('utf-8') }
sub session {
    my $self = shift;
    $self->{session} ||= Plack::Session->new($self->request->env);
}

# -------------------------------------------------------------------------
# Attributes:
sub request           { $_[0]->{request} }
sub req               { $_[0]->{request} }

# -------------------------------------------------------------------------
# Methods:
sub redirect {
    my ($self, $location, $params) = @_;
    my $url = do {
        if ($location =~ m{^https?://}) {
            $location;
        }
        else {
            my $url = $self->req->base;
            $url =~ s{/+$}{};
            $location =~ s{^/+([^/])}{/$1};
            $url .= $location;
        }
    };
    if (my $ref = ref $params) {
        my @ary = $ref eq 'ARRAY' ? @$params : %$params;
        my $uri = URI->new($url);
        $uri->query_form($uri->query_form, map { Encode::encode($self->encoding, $_) } @ary);
        $url = $uri->as_string;

    }
    return $self->create_response(
        302,
        ['Location' => $url],
        []
    );
}

sub uri_for {
    my ($self, $path, $query) = @_;
    my $root = $self->req->base || '/';
    $root =~ s{([^/])$}{$1/};
    $path =~ s{^/}{};

    my @query = !$query ? () : ref $query eq 'HASH' ? %$query : @$query;
    my @q;
    while (my ($key, $val) = splice @query, 0, 2) {
        $val = URL::Encode::url_encode(Encode::encode($self->encoding, $val));
        push @q, "${key}=${val}";
    }
    $root . $path . (scalar @q ? '?' . join('&', @q) : '');
}


sub to_app {
    my ($class, ) = @_;
    return sub { $class->handle_request(shift) };
}

sub handle_request {
    my ($class, $env) = @_;

    my $req = $class->create_request($env);
    my $self = $class->new(
        request => $req,
    );

    my $response;
    for my $code ($self->get_trigger_code('BEFORE_DISPATCH')) {
        $response = $code->($self);
        goto PROCESS_END if Scalar::Util::blessed($response) && $response->isa('Plack::Response');
    }
    $response = $self->dispatch() or die "cannot get any response";
PROCESS_END:
    $self->call_trigger('AFTER_DISPATCH' => $response);

    return $response->finalize;
}

sub render {
    my $self = shift;
    my $html = $self->create_view->render(@_);

    for my $code ($self->get_trigger_code('HTML_FILTER')) {
        $html = $code->($self, $html);
    }

    $html = Encode::encode($self->encoding, $html);
    return $self->create_response(
        200,
        [
            'Content-Type'   => $self->html_content_type,
            'Content-Length' => length($html)
        ],
        [$html],
    );
}

# -------------------------------------------------------------------------
# Raise Error:
my %StatusCode = (
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Large',
    415 => 'Unsupported Media Type',
    416 => 'Request Range Not Satisfiable',
    417 => 'Expectation Failed',
    418 => 'I\'m a teapot',            # RFC 2324
    422 => 'Unprocessable Entity',            # RFC 2518 (WebDAV)
    423 => 'Locked',                          # RFC 2518 (WebDAV)
    424 => 'Failed Dependency',               # RFC 2518 (WebDAV)
    425 => 'No code',                         # WebDAV Advanced Collections
    426 => 'Upgrade Required',                # RFC 2817
    428 => 'Precondition Required',
    429 => 'Too Many Requests',
    431 => 'Request Header Fields Too Large',
    449 => 'Retry with',                      # unofficial Microsoft
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
    506 => 'Variant Also Negotiates',         # RFC 2295
    507 => 'Insufficient Storage',            # RFC 2518 (WebDAV)
    509 => 'Bandwidth Limit Exceeded',        # unofficial
    510 => 'Not Extended',                    # RFC 2774
    511 => 'Network Authentication Required',
);

while ( my ($code, $msg) = each %StatusCode) {
    no strict 'refs';
    *{__PACKAGE__ ."::res_$code"} = sub {
        use strict 'refs';
        my $self = shift;
        my $content = $self->error_html($code, $msg);
        $self->create_response(
            $code,
            [
                'Content-Type' => 'text/html; charset=utf-8',
                'Content-Length' => length($content),
            ],
            [$content]
        );
    }
}

sub error_html {
    my ($self, $code, $msg) = @_;
sprintf q[<!doctype html>
<html>
    <head>
        <meta charset=utf-8 />
    </head>
    <body>
        <div class="code">%s</div>
        <div class="message">%s</div>
    </body>
</html>'], $code, $msg;
}


1;
__END__

=encoding utf-8

=head1 NAME

PhiloPurple - It's new $module

=head1 SYNOPSIS

    use PhiloPurple;

=head1 DESCRIPTION

PhiloPurple is ...

=head1 LICENSE

Copyright (C) Masayuki Matsuki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Masayuki Matsuki E<lt>y.songmu@gmail.comE<gt>

=cut

