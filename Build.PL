use 5.010;
use strict;
use warnings;
use Module::Build;

my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code => <<'SUBCLASS' );

sub ACTION_critique {
    my $self = shift;
    $self->depends_on("test");
    $self->do_system(qw(perlcritic lib/));
}
SUBCLASS

my $builder = $class->new(
    module_name         => 'CPANPLUS::Dist::Slackware',
    license             => 'perl',
    dist_author         => q{Andreas Voegele <voegelas@cpan.org>},
    dist_version_from   => 'lib/CPANPLUS/Dist/Slackware.pm',
    build_requires => {
        'Module::Build' => 0.2808,
        'Test::More' => 0,
    },
    configure_requires => {
        'Module::Build' => 0.2808,
    },
    requires => {
        'perl' => 5.010,
        'CPANPLUS' => 0,
        'Cwd' => 0,
        'File::Find' => 0,
        'File::Spec' => 0,
        'File::Temp' => 0,
        'IO::Compress::Gzip' => 0,
        'IPC::Cmd' => 0,
        'Locale::Maketext::Simple' => 0,
        'Module::CoreList' => 0,
        'Module::Pluggable' => 0,
        'Params::Check' => 0,
        'Pod::Find' => 0,
        'Pod::Simple' => 0,
        'POSIX' => 0,
        'Text::Wrap' => 0,
        'version' => 0.77,
    },
    add_to_cleanup      => [ 'CPANPLUS-Dist-Slackware-*' ],
    create_makefile_pl => 'traditional',
    meta_merge     => {
        resources => {
            repository => 'git://github.com/voegelas/CPANPLUS-Dist-Slackware.git'
        },
    },
);

$builder->create_build_script();
