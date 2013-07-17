package PhiloPurple::Runner;
use strict;
use warnings;

use Plack::Runner;
use Plack::Util;

sub new {
    my ($class, $app, $default) = @_;
    $app = Plack::Util::load_class($app);

    my @argv = @ARGV;

    my @default;
    while (my ($key, $value) = each %$default) {
        push @default, "--$key=$value";
    }
    my $runner = Plack::Runner->new;
    $runner->parse_options(@default, @argv);

    my %options = @{ $runner->{options} };
    delete $options{$_} for qw/listen socket/;
    $app = $app->new(%options);

    bless {app => $app, runner => $runner}, $class;
}

sub run {
    my $self = shift;
    $self->{runner}->run($self->{app}->to_psgi);
}

1;
