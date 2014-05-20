requires 'Clone';
requires 'Config::PL';
requires 'Data::Section::Simple';
requires 'Hash::MultiValue';
requires 'Plack';
requires 'Plack::Middleware::Session';
requires 'Plack::Request::WithEncoding';
requires 'Tiffany';
requires 'URI::QueryParam';
requires 'URL::Encode';
requires 'perl', '5.010';

recommends 'Text::Xslate';
recommends 'URL::Encode::XS';

# Dispatcher::Lite
recommends 'Router::Boom::Method';

# Plugin::ShareDir
recommends 'File::ShareDir';

# Plugin::JSON
recommends 'JSON';

# Plugin::HandleStatic
recommends 'MIME::Base64';

on configure => sub {
    requires 'CPAN::Meta';
    requires 'CPAN::Meta::Prereqs';
    requires 'Module::Build';
};

on test => sub {
    requires 'Test::More', '0.98';
};
