package PhiloPurple::Dispatcher::PHPish;
use strict;
use warnings;
use utf8;

use File::Basename ();
use Path::Tiny;

# TODO: register controllers
sub new { bless {}, shift }

sub dispatch {
    my ($self, $c) = @_;

    my $path_info //= $c->req->env->{PATH_INFO};
    $path_info = '/' if $path_info eq '';
    $path_info =~ s!(?:index)?/+\z!!ms;

    return $c->res_404 if $path_info =~ m![^a-zA-Z0-9/_]!;
    return $c->res_404 if $path_info =~ m!/[^a-zA-Z0-9]!;
    for my $postfix (qw(/index.mt .mt)) {
        my $tmpl = $path_info . $postfix;
        return $c->render($tmpl) if -e $tmpl;
    }
    $c->res_404;
}

1;
