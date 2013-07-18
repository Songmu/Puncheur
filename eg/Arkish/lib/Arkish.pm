package Arkish;
use strict;
use warnings;
use utf8;

use parent 'PhiloPurple';

__PACKAGE__->setting(
    view       => 'Xslate',
    dispatcher => 'Arkish',
);


1;
