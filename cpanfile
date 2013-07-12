requires 'Config::PL';
requires 'Path::Tiny';
requires 'Plack';
requires 'Tiffany';
requires 'URI::QueryParam';
requires 'URL::Encode';
requires 'perl', '5.010';

on configure => sub {
    requires 'CPAN::Meta';
    requires 'CPAN::Meta::Prereqs';
    requires 'Module::Build';
};

on test => sub {
    requires 'Test::More', '0.98';
};
