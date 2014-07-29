requires 'Carp::Always';
requires 'Getopt::Long';
requires 'LWP::UserAgent';
requires 'PDL::Graphics::Simple';
requires 'PDL::Lite';
requires 'PDL::LiteF';
requires 'PDL::Stats';
requires 'Time::Local';
requires 'feature';
requires 'perl', '5.008_005';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.008005';
};

on test => sub {
    requires 'Test::More';
};
