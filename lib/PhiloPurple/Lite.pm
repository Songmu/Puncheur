package PhiloPurple::Lite;
use 5.010;
use warnings;

use PhiloPurple ();
use PhiloPurple::Dispatcher::Lite ();
use Data::Section::Simple ();
use Encode ();
use MIME::Base64 ();

sub import {
    my ($class) = @_;
    my $caller = caller;

    {
        no strict 'refs';
        push @{"$caller\::ISA"}, 'PhiloPurple';

        *{"$caller\::to_psgi"} = sub {
            use strict 'refs';
            my ($self, %opts) = @_;
            $self = $self->new unless ref $self;

            my $app = $self->PhiloPurple::to_psgi;
            if (delete $opts{handle_static} || $self->{handle_static}) {
                my $vpath = $self->template_dir->[0];
                require Plack::App::File;
                my $orig_app = $app;
                my $app_file_1;
                my $app_file_2;

                my $base_dir   = $self->base_dir;
                my $static_dir = File::Spec->catdir( $base_dir, 'static' );
                $app = sub {
                    my $env = shift;
                    my $path_info = $env->{PATH_INFO};
                    if (my $content = $vpath->{$path_info} and $path_info =~ m{^/}) {
                        my $ct = Plack::MIME->mime_type($path_info);
                        state $cache = {};
                        if ($cache->{$caller}{$path_info}) {
                            $content = $cache->{$caller}{$path_info};
                        }
                        else {
                            if ($ct !~ /\b(?:text|xml|javascript|json)\b/) {
                                # binary
                                $content = MIME::Base64::decode_base64($content);
                            }
                            else {
                                $content = Encode::encode($self->encoding, $content);
                            }
                            $cache->{$caller}{$path_info} = $content;
                        }
                        return [200, ['Content-Type' => $ct, 'Content-Length' => length($content)], [$content]];
                    }
                    elsif ($path_info =~ qr{^(?:/robots\.txt|/favicon\.ico)$}) {
                        $app_file_1 ||= Plack::App::File->new({ root => $static_dir });
                        return $app_file_1->call($env);
                    }
                    elsif ($path_info =~ m{^/static/}) {
                        $app_file_2 ||= Plack::App::File->new({ root => $base_dir });
                        return $app_file_2->call($env);
                    }
                    else {
                        return $orig_app->($env);
                    }
                };
            }

            {
                no strict 'refs';
                if (my @middlewares = @{"$caller\::_MIDDLEWARES"}) {
                    use strict 'refs';
                    for my $middleware (@middlewares) {
                        my ($klass, $args) = @$middleware;
                        $klass = Plack::Util::load_class($klass, 'Plack::Middleware');
                        $app = $klass->wrap($app, %$args);
                    }
                }
            }
            return $app;
        };

        *{"$caller\::enable_middleware"} = sub {
            my ($klass, %args) = @_;
            push @{"$caller\::_MIDDLEWARES"}, [$klass, \%args];
        };
        *{"$caller\::enable_session"} = sub {
            use strict 'refs';
            my (%args) = @_;
            $args{state} ||= do {
                require Plack::Session::State::Cookie;
                Plack::Session::State::Cookie->new(httponly => 1); # for security
            };
            require Plack::Middleware::Session;

            my $func = $caller->can('enable_middleware');
            $func->('Plack::Middleware::Session', %args);
        };
    }

    $caller->setting(
        template_dir => [sub {Data::Section::Simple->new($caller)->get_data_section}, 'tmpl'],
        view         => 'Xslate',
    );

    goto do { PhiloPurple::Dispatcher::Lite->can('import') };
}

1;
