package PhiloPurple::Lite;
use strict;
use warnings;

use PhiloPurple ();
use PhiloPurple::Dispatcher::Lite ();
use Data::Section::Simple ();

sub import {
    my ($class) = @_;
    my $caller = caller;

    {
        no strict 'refs';
        push @{"$caller\::ISA"}, 'PhiloPurple';
    }
    # TODO: static
    $caller->setting(
        template_dir => [sub {Data::Section::Simple->new($caller)->get_data_section}, 'tmpl'],
        view         => 'Xslate',
    );

    goto do { PhiloPurple::Dispatcher::Lite->can('import') };
}

1;
