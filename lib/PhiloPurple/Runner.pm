package PhiloPurple::Runner;
use strict;
use warnings;

use Plack::Runner;
use Plack::Util;

sub new {
    my ($class, $app, $plackup_options, $app_options) = @_;
    $app = Plack::Util::load_class($app);

    my @argv = @ARGV;

    my @default;
    while (my ($key, $value) = each %$plackup_options) {
        push @default, "--$key=$value";
    }
    my $runner = Plack::Runner->new;
    $runner->parse_options(@default, @argv);

    my %options;
    if ($app->can('parse_options')) {
        %options = $app->parse_options(@argv);
    }
    else {
        %options = @{ $runner->{options} };
        delete $options{$_} for qw/listen socket/;
    }

    bless {
        app => $app,
        runner   => $runner,
        app_options => {
            %{ $app_options || {} },
            %options,
        }
    }, $class;
}

sub run {
    my $self = shift;
    my %opts = @_ == 1 ? %{$_[0]} : @_;

    my $app_options = $self->{app_options};
    my $psgi = $self->{app}->new(%$app_options, %opts)->to_psgi;
    $self->{runner}->run($psgi);
}

1;
