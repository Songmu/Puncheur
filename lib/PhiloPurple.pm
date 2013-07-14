package PhiloPurple;
use 5.010;;
use strict;
use warnings;

our $VERSION = "0.01";

use Carp ();
use Clone qw/clone/;
use Config::PL ();
use Encode;
use File::Spec;
use JSON;
use URL::Encode;
use Plack::Session;
use PhiloPurple::Request;
use PhiloPurple::Response;
use PhiloPurple::Trigger qw/add_trigger call_trigger get_trigger_code/;
use Module::Load ();
use Scalar::Util ();

sub new {
    my $base_class = shift;
    my %args = @_ == 1 ? %{ $_[0] } : @_;

    $args{app_name} = 'PhiloPurple::_Sandbox'
        if $base_class eq __PACKAGE__ && !defined $args{app_name};

    my $class = $args{app_name} // $base_class;
    if ($args{app_name}) {
        local $@;
        eval {
            Module::Load::load($class);
            $class->import if $class->can('import');
        };
        if ($@) {
            no strict 'refs'; @{"$class\::ISA"} = ($base_class);
        }
        Carp::croak "$class is not $base_class class" unless $class->isa($base_class);
    }
    bless { %args }, $class;
}

# -------------------------------------------------------------------------
# Hook points:
# You can override these methods.
sub create_request  { PhiloPurple::Request->new($_[1], $_[0]) }
sub create_response { shift; PhiloPurple::Response->new(@_) }

sub template_dir {
    my $self = shift;
    my $class = $self->app_name;

    my $tmpl = ref $self && $self->{template_dir} ? $self->{template_dir} : 'tmpl';
    $tmpl = File::Spec->catfile($self->base_dir, $tmpl);

    $self->_cache_method($tmpl);
}

sub view {
    my $self = shift;
    my $class = $self->app_name;

    require Tiffany;
    my @args = ref $self && $self->{view} ? %{ $self->{view} } : ('Text::MicroTemplate::Extended', {
        include_path => $self->template_dir,
        template_args => { c => sub { $self }, }
    });
    my $view = Tiffany->load(@args);

    $self->_cache_method($view);
}

sub dispatcher {
    my $self = shift;
    my $class = $self->app_name;

    my $dispatcher_pkg = $class . '::Dispatcher';
    local $@;
    eval {
        Module::Load::load($dispatcher_pkg);
        $dispatcher_pkg->import if $dispatcher_pkg->can('import');
    };
    if ($@) {
        my $base_dispatcher_class = 'PhiloPurple::Dispatcher::PHPish';
        Module::Load::load($base_dispatcher_class);
        no strict 'refs'; @{"$dispatcher_pkg\::ISA"} = ($base_dispatcher_class);
    }

    my $dispatcher = $dispatcher_pkg->new($self);

    $self->_cache_method($dispatcher);
}

sub dispatch {
    my $self = shift;
    $self->dispatcher->dispatch($self);
}

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
# Util

sub add_method {
    my ($klass, $method, $code) = @_;
    no strict 'refs';
    *{"${klass}::${method}"} = $code;
}

sub _cache_method {
    my ($self, $stuff) = @_;
    my $class = $self->app_name;

    my (undef, undef, undef, $sub) = caller(1);
    $sub = +(split /::/, $sub)[-1];
    my $code = sub { $stuff };
    $class->add_method($sub, $code);
    $stuff;
}

sub base_dir {
    my $self = shift;
    my $class = $self->app_name;

    my $base_dir = do {
        my $path = $class;
        $path =~ s!::!/!g;
        if (!$self->{app_name} and my $libpath = $INC{"$path.pm"}) {
            $libpath =~ s!\\!/!g; # win32
            $libpath =~ s!(?:blib/)?lib/+$path\.pm$!!;
            File::Spec->rel2abs($libpath || './');
        } else {
            File::Spec->rel2abs('./');
        }
    };

    $class->_cache_method($base_dir);
}

sub app_name {
    my $self = shift;
    ref $self || $self;
}

sub mode_name  { $ENV{PLACK_ENV} }
sub debug_mode { $ENV{PHILOPURPLE_DEBUG} }

sub load_config {
    my $self = shift;
    my $config_file = File::Spec->catfile($self->base_dir, 'config', 'common.pl');
    -e $config_file ? Config::PL::config_do($config_file) : {};
}
sub config {
    my $self = shift;
    my $class = $self->app_name;

    my $config = $class->load_config;
    $self->_cache_method($config);
}

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


sub to_psgi {
    my ($self, ) = @_;
    return sub { $self->handle_request(shift) };
}

sub handle_request {
    my ($self, $env) = @_;

    my $c = $self->clone;
    $c->{request} = $c->create_request($env);

    my $response;
    for my $code ($c->get_trigger_code('BEFORE_DISPATCH')) {
        $response = $code->($c);
        goto PROCESS_END if Scalar::Util::blessed($response) && $response->isa('Plack::Response');
    }
    $response = $c->dispatch or die "cannot get any response";
PROCESS_END:
    $c->call_trigger('AFTER_DISPATCH' => $response);

    return $response->finalize;
}

sub render {
    my $self = shift;
    my $html = $self->view->render(@_);

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

sub res_json {
    my ($self, $data) = @_;

    state $json = JSON->new->utf8;
    my $body = eval {
        $json->encode($data);
    };
    local $@;
    if (my $err = $@) {
        Carp::croak $err;
    }

    return $self->create_response(
        200,
        [
            'Content-type'           => 'application/json',
            ### For IE 9 or later. See http://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2013-1297
            'X-Content-Type-Options' => 'nosniff',
            ### Suppress loading web-page into iframe. See http://blog.mozilla.org/security/2010/09/08/x-frame-options/
            'X-Frame-Options'        => 'DENY',
            ### no public cache
            'Cache-Control'          => 'private',
            'Content-Length'         => length($body)
        ],
        [ $body ]
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
</html>], $code, $msg;
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

