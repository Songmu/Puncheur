package MonMonMon;
use strict;
use warnings;
use utf8;

use parent 'PhiloPurple';

sub bootstrap {
    my $class = shift;
    my $self = $class->new(
        view => 'Xslate',
    );
}

1;
