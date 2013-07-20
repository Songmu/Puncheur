package Puncheur::Plugin::ShareDir;
use 5.010;
use warnings;

use File::Spec;
use File::ShareDir ();
use List::Util qw(first);

our @EXPORT = qw/share_dir/;

sub share_dir {
    my $c = shift;
    my $klass = ref $c || $c;

    state $SHARE_DIR_CACHE;
    $SHARE_DIR_CACHE->{$klass} ||= sub {
        my $d1 = File::Spec->catfile($c->base_dir, 'share');
        return $d1 if -d $d1;

        my $dist = first { $_ ne 'Puncheur' && $_->isa('Puncheur') } reverse @{mro::get_linear_isa(ref $c || $c)};
           $dist =~ s!::!-!g;
        my $d2 = File::ShareDir::dist_dir($dist);
        return $d2 if -d $d2;

        return $d1;
    }->();
}

1;
