package CPANPLUS::Dist::Slackware;

use strict;
use warnings;

use base qw(CPANPLUS::Dist::Base);

use English qw( -no_match_vars );

use CPANPLUS::Dist::Slackware::PackageDescription;
use CPANPLUS::Error;

use Cwd qw();
use File::Find qw();
use File::Spec qw();
use IO::Compress::Gzip qw($GzipError);
use IPC::Cmd qw();
use Locale::Maketext::Simple ( Style => 'gettext' );
use Params::Check qw();

local $Params::Check::VERBOSE = 1;

our $VERSION = '0.01';

my $README_SLACKWARE = 'README.SLACKWARE';

my $PERL_MM_OPT = << 'END_PERL_MM_OPT';
INSTALLDIRS=vendor
INSTALLVENDORMAN1DIR=/usr/man/man1
INSTALLVENDORMAN3DIR=/usr/man/man3
END_PERL_MM_OPT

my $PERL_MB_OPT = << 'END_PERL_MB_OPT';
--installdirs vendor
--config installvendorman1dir=/usr/man/man1
--config installvendorman3dir=/usr/man/man3
END_PERL_MB_OPT

my $NONROOT_WARNING = <<'END_NONROOT_WARNING';
In order to manage packages as a non-root user, which is highly recommended,
you must have sudo and, optionally, fakeroot.
END_NONROOT_WARNING

sub format_available {
    my $missing_programs_count = 0;
    for my $program (
        qw(/sbin/makepkg /sbin/installpkg /sbin/upgradepkg /sbin/removepkg))
    {
        if ( !IPC::Cmd::can_run($program) ) {
            error(
                loc(q{You do not have '%1' -- '%2' not available}, $program,
                    __PACKAGE__
                )
            );
            ++$missing_programs_count;
        }
    }
    return ( $missing_programs_count == 0 );
}

sub init {
    my $dist = shift;

    my $status = $dist->status;

    $status->mk_accessors(
        qw(_pkgdesc _fakeroot_cmd _file_cmd _run_perl_cmd _strip_cmd));

    $status->_fakeroot_cmd( IPC::Cmd::can_run('fakeroot') );
    $status->_file_cmd( IPC::Cmd::can_run('file') );
    $status->_run_perl_cmd( IPC::Cmd::can_run('cpanp-run-perl') );
    $status->_strip_cmd( IPC::Cmd::can_run('strip') );

    return 1;
}

sub prepare {
    my ( $dist, @params ) = @_;

    my $status = $dist->status;
    my $module = $dist->parent;

    my $pkgdesc = CPANPLUS::Dist::Slackware::PackageDescription->new(
        module => $module );
    $status->_pkgdesc($pkgdesc);

    $status->dist( $pkgdesc->outputname );

    umask oct '022';

    {

        # CPANPLUS::Dist:MM does not accept multiple options in
        # makemakerflags.  Thus all options have to be passed via
        # environment variables.
        local $ENV{PERL_MM_OPT}   = $PERL_MM_OPT;
        local $ENV{PERL_MB_OPT}   = $PERL_MB_OPT;
        local $ENV{MODULEBUILDRC} = 'NONE';

        # Unfortunately, the Module::Build version shipped with Slackware
        # Linux 13.1 and below does not support PERL_MB_OPT.  To keep things
        # simple, the "buildflags" option is set if an old Perl interpreter is
        # installed.
        if ( $PERL_VERSION lt v5.12.0 ) {
            my %hash = @params;
            $hash{buildflags} = $PERL_MB_OPT;
            @params = %hash;
        }

        # We are not allowed to write to XML/SAX/ParserDetails.ini.
        local $ENV{SKIP_SAX_INSTALL} = 1;

        $dist->SUPER::prepare(@params) or return;
    }

    return $status->prepared(1);
}

sub create {
    my ( $dist, @params ) = @_;

    my $param_ref = $dist->_parse_params(@params) or return;
    my $status = $dist->status;

    {

        # Some tests fail if PERL_MM_OPT and PERL_MB_OPT are set during the
        # create stage.
        delete local $ENV{PERL_MM_OPT};
        delete local $ENV{PERL_MB_OPT};
        local $ENV{MODULEBUILDRC} = 'NONE';

        $dist->SUPER::create(@params) or return;

        $status->created(0);

        $dist->_fake_install($param_ref) or return;
    }

    $dist->_compress_manual_pages($param_ref) or return;

    $dist->_install_docfiles($param_ref) or return;

    $dist->_process_installed_files($param_ref) or return;

    $dist->_make_installdir($param_ref) or return;

    $dist->_write_config_files_to_doinst_sh($param_ref) or return;

    $dist->_write_slack_desc($param_ref) or return;

    $dist->_makepkg($param_ref) or return;

    return $status->created(1);
}

sub install {
    my ( $dist, @params ) = @_;

    my $param_ref = $dist->_parse_params(@params) or return;
    my $status = $dist->status;

    $dist->_installpkg($param_ref) or return;

    return $status->installed(1);
}

sub _parse_params {
    my ( $dist, %params ) = @_;

    my $module = $dist->parent;
    my $cb     = $module->parent;
    my $conf   = $cb->configure_object;

    my $param_ref;
    {
        local $Params::Check::ALLOW_UNKNOWN = 1;
        my $tmpl = {
            force   => { default => $conf->get_conf('force') },
            verbose => { default => $conf->get_conf('verbose') },
            make    => { default => $conf->get_program('make') },
            perl    => { default => $EXECUTABLE_NAME },
        };
        $param_ref = Params::Check::check( $tmpl, \%params ) or return;
    }
    return $param_ref;
}

sub _run_perl {
    my $dist = shift;

    my $status = $dist->status;

    my $run_perl_cmd = $status->_run_perl_cmd;
    return $run_perl_cmd if $run_perl_cmd;

    my $perl_wrapper
        = 'use strict; BEGIN { my $old = select STDERR; $|++;'
        . ' select $old; $|++; $0 = shift(@ARGV); my $rv = do($0);'
        . ' die $@ if $@; }';
    return ( '-e', $perl_wrapper );
}

sub _fake_install {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;
    my $srcname = $module->module;

    my $verbose = $param_ref->{verbose};

    my $wrksrc = $module->status->extract;
    if ( !$wrksrc ) {
        error( loc(q{No dir found to operate on!}) );
        return;
    }

    my $destdir = $pkgdesc->destdir;

    my $cmd;
    my $installer_type = $module->status->installer_type;
    if ( $installer_type eq 'CPANPLUS::Dist::MM' ) {
        my $make = $param_ref->{make};
        $cmd = [ $make, 'install', "DESTDIR=$destdir" ];
    }
    elsif ( $installer_type eq 'CPANPLUS::Dist::Build' ) {
        my $perl     = $param_ref->{perl};
        my @run_perl = $dist->_run_perl;
        $cmd = [ $perl, @run_perl, 'Build', 'install', "destdir=$destdir" ];
    }
    else {
        error( loc( q{Unknown type '%1'}, $installer_type ) );
        return;
    }

    msg( loc( q{Staging '%1' in '%2'}, $srcname, $pkgdesc->destdir ) );

    return $dist->_run_command( $cmd,
        { dir => $wrksrc, verbose => $verbose } );
}

sub _makepkg {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $conf    = $cb->configure_object;
    my $pkgdesc = $status->_pkgdesc;

    my $verbose = $param_ref->{verbose};
    my $destdir = $pkgdesc->destdir;

    my $cmd = [ '/sbin/makepkg', '-l', 'y', '-c', 'y', $pkgdesc->outputname ];
    if ( $EFFECTIVE_USER_ID > 0 ) {
        my $fakeroot = $status->_fakeroot_cmd;
        if ($fakeroot) {
            unshift @{$cmd}, $fakeroot;
        }
        else {
            my $sudo = $conf->get_program('sudo');
            if ($sudo) {
                unshift @{$cmd}, $sudo;

                my $chown = [ $sudo, '/bin/chown', '-R', '0:0', $destdir ];
                $dist->_run_command($chown) or return;
            }
            else {
                error( loc($NONROOT_WARNING) );
                return;
            }
        }
    }

    msg( loc( q{Creating package '%1'}, $pkgdesc->outputname ) );

    return $dist->_run_command( $cmd,
        { dir => $destdir, verbose => $verbose } );
}

sub _installpkg {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $conf    = $cb->configure_object;
    my $pkgdesc = $status->_pkgdesc;

    my $verbose = $param_ref->{verbose};

    my $cmd = [
        '/sbin/upgradepkg', '--install-new',
        '--reinstall',      $pkgdesc->outputname
    ];
    if ( $EFFECTIVE_USER_ID > 0 ) {
        my $sudo = $conf->get_program('sudo');
        if ($sudo) {
            unshift @{$cmd}, $sudo;
        }
        else {
            error( loc($NONROOT_WARNING) );
            return;
        }
    }

    msg( loc( q{Installing package '%1'}, $pkgdesc->outputname ) );

    return $dist->_run_command( $cmd, { verbose => $verbose } );
}

sub _compress_manual_pages {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $pkgdesc = $status->_pkgdesc;

    my $mandir = File::Spec->catdir( $pkgdesc->destdir, 'usr', 'man' );
    return 1 if !-d $mandir;

    my $fail   = 0;
    my $wanted = sub {
        my $filename = $_;

        # Skip files that are already compressed.
        return if $filename =~ /\.gz$/;

        if ( -l $filename ) {
            my $target = $dist->_readlink($filename);
            if ($target) {
                if ( $dist->_symlink( "$target.gz", "$filename.gz" ) ) {
                    if ( !$dist->_unlink($filename) ) {
                        ++$fail;
                    }
                }
                else {
                    ++$fail;
                }
            }
            else {
                ++$fail;
            }
        }
        elsif ( -f $filename ) {
            if ( !$dist->_gzip($filename) ) {
                ++$fail;
            }
        }
    };
    File::Find::find( $wanted, $mandir );

    return ( $fail ? 0 : 1 );
}

sub _install_docfiles {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $wrksrc = $module->status->extract;
    if ( !$wrksrc ) {
        error( loc(q{No dir found to operate on!}) );
        return;
    }

    my @docfiles = $pkgdesc->docfiles;

    # Create docdir.
    my $docdir = File::Spec->catdir( $pkgdesc->destdir, $pkgdesc->docdir );
    $cb->_mkdir( dir => $docdir ) or return;

    # Create README.SLACKWARE.
    my $readme = $pkgdesc->readme_slackware;
    my $readmefile = File::Spec->catfile( $docdir, $README_SLACKWARE );
    $dist->_with_output_to_file( $readmefile, '>',
        sub { print $readme or die "Write error\n" } )
        or return;

    # Create perl-Some-Module.SlackBuild.
    my $script = $pkgdesc->build_script;
    my $scriptfile
        = File::Spec->catfile( $docdir, $pkgdesc->name . '.SlackBuild' );
    $dist->_with_output_to_file( $scriptfile, '>',
        sub { print $script or die "Write error\n" } )
        or return;

    # Copy docfiles like README and Changes.
    my $fail = 0;
    for my $docfile (@docfiles) {
        my $from = File::Spec->catfile( $wrksrc, $docfile );
        if ( !$cb->_copy( file => $from, to => $docdir ) ) {
            ++$fail;
        }
    }

    return ( $fail ? 0 : 1 );
}

sub _process_installed_files {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $pkgdesc = $status->_pkgdesc;

    my $fail   = 0;
    my $wanted = sub {
        my $filename = $_;

        my @stat = $dist->_lstat($filename);
        return if !@stat;

        # Skip symbolic links.
        return if -l _;

        # Sanitize the file modes.
        my $perm = ( $stat[2] & oct '0755' ) | oct '0200';
        if ( !$dist->_chmod( $perm, $filename ) ) {
            ++$fail;
        }

        if ( -d $filename ) {

            # Remove empty directories.
            rmdir $filename;
        }
        elsif ( -f $filename ) {
            if (   $filename eq 'perllocal.pod'
                || $filename eq '.packlist'
                || ( $filename =~ /\.bs$/ && -z $filename ) )
            {
                if ( !$dist->_unlink($filename) ) {
                    ++$fail;
                }
            }
            else {
                my $type = $dist->_filetype($filename);
                if ($type) {
                    if ( $type =~ /ELF.+(?:executable|shared object)/s ) {
                        if ( !$dist->_strip($filename) ) {
                            ++$fail;
                        }
                    }
                }
            }
        }
    };
    File::Find::finddepth( $wanted, $pkgdesc->destdir );

    return ( $fail ? 0 : 1 );
}

sub _make_installdir {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $installdir = File::Spec->catdir( $pkgdesc->destdir, 'install' );
    return $cb->_mkdir( dir => $installdir );
}

sub _write_config_files_to_doinst_sh {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $destdir = $pkgdesc->destdir;

    return 1 if !-d File::Spec->catdir( $destdir, 'etc' );

    my $orig_dir = Cwd::cwd();
    if ( !$cb->_chdir( dir => $destdir ) ) {
        return;
    }

    # Find and rename the configuration files.
    my $fail = 0;
    my @conffiles;
    my $wanted = sub {
        my $filename = $_;

        # Skip files that have already been renamed.
        return if $filename =~ /\.new$/;

        if ( -l $filename || -f $filename ) {
            if ( !$cb->_move( file => $filename, to => "$filename.new" ) ) {
                ++$fail;
            }
            push @conffiles, $filename;
        }
    };
    File::Find::find( { wanted => $wanted, no_chdir => 1 }, 'etc' );

    if ( !$cb->_chdir( dir => $orig_dir ) ) {
        ++$fail;
    }

    return 0 if $fail;
    return 1 if !@conffiles;

    # List the configuration files in README.SLACKWARE.
    $dist->_write_config_files_to_readme_slackware(@conffiles) or return;

    # Add a config function to doinst.sh.
    my $script = $pkgdesc->config_function;
    for my $conffile (@conffiles) {
        $conffile =~ s/('+)/'"$1"'/g;    # Quote single quotes.
        $script .= "config '$conffile.new'\n";
    }

    my $installdir = File::Spec->catdir( $pkgdesc->destdir, 'install' );
    my $doinstfile = File::Spec->catfile( $installdir, 'doinst.sh' );
    return $dist->_with_output_to_file( $doinstfile, '>',
        sub { print $script or die "Write error\n" } );
}

sub _write_config_files_to_readme_slackware {
    my ( $dist, @conffiles ) = @_;

    my $status  = $dist->status;
    my $pkgdesc = $status->_pkgdesc;

    my $readme
        = "\n"
        . "This package provides the following configuration files:\n" . "\n"
        . join "\n", map {"/$_"} @conffiles;

    my $docdir = File::Spec->catdir( $pkgdesc->destdir, $pkgdesc->docdir );
    my $readmefile = File::Spec->catfile( $docdir, $README_SLACKWARE );
    return $dist->_with_output_to_file( $readmefile, '>>',
        sub { print $readme or die "Write error\n" } );
}

sub _write_slack_desc {
    my ( $dist, $param_ref ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $installdir = File::Spec->catdir( $pkgdesc->destdir, 'install' );
    my $descfile = File::Spec->catfile( $installdir, 'slack-desc' );
    my $desc = $pkgdesc->slack_desc;
    return $dist->_with_output_to_file( $descfile, '>',
        sub { print $desc or die "Write error\n" } );
}

sub _with_output_to_file {
    my ( $dist, $filename, $mode, $coderef ) = @_;

    my $fh;
    if ( !open $fh, $mode, $filename ) {
        error(
            loc( q{Could not create file '%1': %2}, $filename, $OS_ERROR ) );
        return;
    }

    my $fail = not eval {
        local *STDOUT = $fh;
        &{$coderef};
    };
    if ($fail) {
        error( loc( q{Could not write to file '%1'}, $filename ) );
        ++$fail;
    }

    if ( !close $fh ) {
        error(
            loc( q{Could not close file '%1': %2}, $filename, $OS_ERROR ) );
        ++$fail;
    }

    return ( $fail ? 0 : 1 );
}

sub _run_command {
    my ( $dist, $cmd, $param_ref ) = @_;

    my $module = $dist->parent;
    my $cb     = $module->parent;

    my $dir     = $param_ref->{dir};
    my $verbose = $param_ref->{verbose};
    my $buf_ref = $param_ref->{buffer};
    if ( !$buf_ref ) {
        my $buf;
        $buf_ref = \$buf;
    }

    my $orig_dir;
    if ($dir) {
        $orig_dir = Cwd::cwd();
        if ( !$cb->_chdir( dir => $dir ) ) {
            return;
        }
    }

    my $fail = 0;
    if (!IPC::Cmd::run(
            command => $cmd,
            buffer  => $buf_ref,
            verbose => $verbose
        )
        )
    {
        my $cmdline = join q{ }, @{$cmd};
        error( loc( q{Could not run '%1': %2}, $cmdline, ${$buf_ref} ) );
        ++$fail;
    }

    if ($orig_dir) {
        if ( !$cb->_chdir( dir => $orig_dir ) ) {
            ++$fail;
        }
    }

    return ( $fail ? 0 : 1 );
}

sub _filetype {
    my ( $dist, $filename ) = @_;

    my $status = $dist->status;
    my $file_cmd = $status->_file_cmd || return;

    my $cmd = [ $file_cmd, '-b', $filename ];
    my $filetype;
    $dist->_run_command( $cmd, { buffer => \$filetype } ) or return;
    if ($filetype) {
        chomp $filetype;
    }
    return $filetype;
}

sub _strip {
    my ( $dist, @filenames ) = @_;

    my $status = $dist->status;
    my $strip_cmd = $status->_strip_cmd || return 1;

    my $cmd = [ $strip_cmd, '--strip-unneeded', @filenames ];
    return $dist->_run_command($cmd);
}

sub _gzip {
    my ( $dist, @filenames ) = @_;

    my $fail = 0;
    for my $filename (@filenames) {
        if ( IO::Compress::Gzip::gzip( $filename, "$filename.gz" ) ) {
            if ( !$dist->_unlink($filename) ) {
                ++$fail;
            }
        }
        else {
            error(
                loc(q{Could not compress file '%1': %2}, $filename,
                    $GzipError
                )
            );
            ++$fail;
        }
    }
    return ( $fail ? 0 : 1 );
}

sub _lstat {
    my ( $dist, $filename ) = @_;

    my @stat = lstat $filename;
    if ( !@stat ) {
        error( loc( q{Could not lstat '%1': %2}, $filename, $OS_ERROR ) );
    }
    return @stat;
}

sub _chmod {
    my ( $dist, $mode, @filenames ) = @_;

    my $fail = 0;
    for my $filename (@filenames) {
        if ( !chmod $mode, @filenames ) {
            error( loc( q{Could not chmod '%1': %2}, $filename, $OS_ERROR ) );
            ++$fail;
        }
    }
    return ( $fail ? 0 : 1 );
}

sub _unlink {
    my ( $dist, @filenames ) = @_;

    my $fail = 0;
    for my $filename (@filenames) {
        if ( !unlink $filename ) {
            error(
                loc( q{Could not unlink '%1': %2}, $filename, $OS_ERROR ) );
            ++$fail;
        }
    }
    return ( $fail ? 0 : 1 );
}

sub _symlink {
    my ( $dist, $oldfile, $newfile ) = @_;

    my $fail = 0;
    if ( !symlink $oldfile, $newfile ) {
        error(
            loc(q{Could not symlink '%1' to '%2': %3},
                $oldfile, $newfile, $OS_ERROR
            )
        );
        ++$fail;
    }
    return ( $fail ? 0 : 1 );
}

sub _readlink {
    my ( $dist, $filename ) = @_;

    my $target = readlink $filename;
    if ( !$target ) {
        error( loc( q{Could not readlink '%1': %2}, $filename, $OS_ERROR ) );
    }
    return $target;
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware - Install Perl distributions on Slackware Linux

=head1 VERSION

This documentation refers to C<CPANPLUS::Dist::Slackware> version 0.01.

=head1 SYNOPSIS

    ### from the cpanp interactive shell
    $ cpanp
    CPAN Terminal> i Some::Module --format=CPANPLUS::Dist::Slackware

    ### using the command-line tool
    $ cpan2dist --format CPANPLUS::Dist::Slackware Some::Module

=head1 DESCRIPTION

Do you prefer to manage all software in your operating system's native package
format?

This CPANPLUS plugin creates Slackware compatible packages from Perl
distributions.  You can either install the created packages using the API
provided by CPANPLUS, or manually via C<installpkg>.

=head2 Using C<CPANPLUS::Dist::Slackware>

Start an interactive shell to edit the CPANPLUS settings:

    $ cpanp
    CPAN Terminal> s reconfigure

Once CPANPLUS is configured, modules can be installed.  Example:

    CPAN Terminal> i Smart::Comments --format=CPANPLUS::Dist::Slackware

You can make C<CPANPLUS::Dist::Slackware> your default format by setting the
C<dist_type> key:

    CPAN Terminal> s conf dist_type CPANPLUS::Dist::Slackware

CPANPLUS sometimes fails to show interactive prompts if the C<verbose> option
is not set.  Thus you might want to enable verbose output:

    CPAN Terminal> s conf verbose 1

Make your changes permanent:

    CPAN Terminal> s save

User settings are stored in F<$HOME/.cpanplus/lib/CPANPLUS/Config/User.pm>.

Packages may also be created from the command-line.  Example:

    $ cpan2dist --format CPANPLUS::Dist::Slackware Mojolicious
    $ sudo /sbin/installpkg /tmp/perl-Mojolicious-2.43-i486-1_CPANPLUS.tgz

=head2 Managing packages as a non-root user

The C<sudo> command must be installed and configured.  If the C<fakeroot>
command is installed, packages will be built without the help of C<sudo>.
Installing packages still requires root privileges though.

=head2 Documentation files

README files and changelogs are stored in a package-specific subdirectory in
F</usr/doc>.  In addition, a F<README.SLACKWARE> file that lists the package's
build dependencies is supplied.

=head2 Configuration files

Few Perl distributions provide configuration files in F</etc> but if such a
distribution is updated you have to check for new configuration files.  The
package's F<README.SLACKWARE> file lists the configuration files.  Updated
configuration files have got the filename extension ".new" and must be merged
by the system administrator.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< CPANPLUS::Dist::Slackware->format_available >>

Returns a boolean indicating whether or not Slackware's package management
commands are available.

    $is_available = CPANPLUS::Dist::Slackware->format_available();

=item B<< $dist->init >>

Sets up the C<CPANPLUS::Dist::Slackware> object for use.  Creates all the
needed status accessors.

    $success = $dist->init();

Called automatically whenever a new C<CPANPLUS::Dist> object is created.

=item B<< $dist->prepare(%params) >>

Runs C<perl Makefile.PL> or C<perl Build.PL> and determines what prerequisites
this distribution declared.

    $success = $dist->prepare(
        perl           => '/path/to/perl',
        force          => (1|0),
        verbose        => (1|0)
    );

If you set C<force> to true, it will go over all the stages of the C<prepare>
process again, ignoring any previously cached results.

Returns true on success and false on failure.

You may then call C<< $dist->create >> on the object to build the distribution
and to create a Slackware compatible package.

=item B<< $dist->create(%params) >>

Builds the distribution, runs the test suite and executes C<makepkg> to create
a Slackware compatible package.  Also scans for and attempts to satisfy any
prerequisites the module may have.

    $success = $dist->create(
        perl       => '/path/to/perl',
        make       => '/path/to/make',
        skiptest   => (1|0),
        force      => (1|0),
        verbose    => (1|0)
    );

If you set C<skiptest> to true, the test stage will be skipped.  If you set
C<force> to true, C<create> will go over all the stages of the build process
again, ignoring any previously cached results.  It will also ignore a bad
return value from the test stage and still allow the operation to return true.

Returns true on success and false on failure.

You may then call C<< $dist->install >> on the object to actually install the
created package.

=item B<< $dist->install(%params) >>

Installs the package using C<upgradepkg --install-new --reinstall>.  If the
package is already installed on the system, the existing package will be
replaced by the new package.

    $success = $dist->install(verbose => (1|0));

Returns true on success and false on failure.

=back

=head1 DIAGNOSTICS

=over 4

=item B<< In order to manage packages as a non-root user... >>

You are using CPANPLUS as a non-root user but C<sudo> is either not installed
or not configured.

=item B<< You do not have '/sbin/makepkg'... >>

The Slackware package management commands are not installed.

=item B<< Could not chdir into DIR >>

C<CPANPLUS::Dist::Slackware> could not change its current directory while
building the package.

=item B<< Could not create directory DIR >>

A directory could not be created.  Are the parent directory's owner or
mode bits wrong?  Is the file system mounted read-only?

=item B<< Could not create file FILE >>

A file could not be opened for writing.  Check your file and directory
permissions!

=item B<< Could not write to file FILE >>

Is a file system, e.g. F</tmp> full?

=item B<< Could not compress file FILE >>

A manual page could not be compressed.

=item B<< Failed to copy FILE1 to FILE2 >>

A file could not be copied.

=item B<< Failed to move FILE1 to FILE2 >>

A file could not be renamed.

=item B<< Could not run COMMAND >>

An external command failed to execute.

=item B<< No dir found to operate on! >>

For some reason, the Perl distribution's archive has not been extracted by
CPANPLUS.

=item B<< Unknown type 'CPANPLUS::Dist::WHATEVER' >>

C<CPANPLUS::Dist::Slackware> supports C<CPANPLUS::Dist::MM> and
C<CPANPLUS::Dist::Build>.

=back

=head1 CONFIGURATION AND ENVIRONMENT

Similar to the build scripts provided by L<http://slackbuilds.org/>
C<CPANPLUS::Dist::Slackware> respects the following environment variables:

=over 4

=item B<TMP>

The staging directory where the Perl distributions are temporarily installed.
Defaults to F<$TMPDIR/CPANPLUS> or to F</tmp/CPANPLUS> if C<$ENV{TMPDIR}> is
not set.

=item B<OUTPUT>

The package output directory where all created packages are stored.  Defaults
to F<$TMPDIR> or F</tmp>.

=item B<ARCH>

The package architecture.  Defaults to "i486" on x86-based platforms, to "arm"
on ARM-based platforms and to the system's hardware identifier, i.e. the
output of C<uname -m> on all other platforms.

=item B<TAG>

This tag is added to the package filename.  Defaults to "_CPANPLUS".

=item B<PKGTYPE>

The package extension.  Defaults to "tgz".  May be set to "tbz", "tlz" or
"txz".  The proper compression utility, i.e. C<gzip>, C<bzip2>, C<lzma>, or
C<xz>, needs to be installed on the machine.

=back

The environment variable B<BUILD> is ignored as packages may be built
recursively.

=head1 DEPENDENCIES

Requires the Slackware package management commands C<makepkg>, C<installpkg>,
C<updatepkg>, and C<removepkg>.  Other required GNU/Linux commands are
C<file>, C<gcc>, C<make>, and C<strip>.

In order to manage packages as a non-root user, which is highly recommended,
you must have C<sudo> and, optionally, C<fakeroot>.  You can download a script
that builds C<fakeroot> from L<http://slackbuilds.org/>.

C<CPANPLUS::Dist::Slackware> requires the modules C<CPANPLUS>, C<Cwd>,
C<File::Find>, C<File::Spec>, C<IO::Compress::Gzip>, C<IPC:Cmd>,
C<Locale::Maketext::Simple>, and C<Params::Check>, which are all provided by
Perl 5.10.

=head1 INCOMPATIBILITIES

Packages created with C<CPANPLUS::Dist::Slackware> may conflict with
packages from L<http://slackbuilds.org/>.

=head1 SEE ALSO

cpanp(1), cpan2dist(1), sudo(8), fakeroot(1), C<CPANPLUS::Dist::MM>,
C<CPANPLUS::Dist::Build>, C<CPANPLUS::Dist::Base>

=head1 AUTHOR

Andreas Voegele, C<< <andreas at andreasvoegele.com> >>

=head1 BUGS AND LIMITATIONS

CPANPLUS sometimes fails to show interactive prompts if the C<verbose> option
is not set.  This has been reported as bug #47818 and bug
#72095 at L<http://rt.cpan.org/>.

Please report any bugs to C<bug-cpanplus-dist-slackware at rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org/>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 Andreas Voegele

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

=cut
