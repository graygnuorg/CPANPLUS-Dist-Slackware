package CPANPLUS::Dist::Slackware::Plugin::Mail::SpamAssassin;

use strict;
use warnings;

use File::Spec qw();

our $VERSION = '0.01';

sub available {
    my ( $plugin, $dist ) = @_;
    return ( $dist->parent->package_name eq 'Mail-SpamAssassin' );
}

sub pre_package {
    my ( $plugin, $dist ) = @_;

    $plugin->_install_init_script($dist) or return;
    $plugin->_install_docfiles($dist)    or return;

    return 1;
}

sub _install_init_script {
    my ( $plugin, $dist ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $destdir = $pkgdesc->destdir;

    my $wrksrc = $module->status->extract;
    return if !$wrksrc;

    my $script;
    my $srcfile
        = File::Spec->catdir( $wrksrc, 'spamd', 'slackware-rc-script.sh' );
    if ( -f $srcfile ) {
        $script = $dist->_read_file($srcfile);
    }
    if ($script) {
        $script =~ s/^SNAME=rc\.spamassassin/SNAME=rc.spamd/xms;

        my $sysconfdir = File::Spec->catdir( $destdir, 'etc' );

        my $rcdir = File::Spec->catdir( $sysconfdir, 'rc.d' );
        $cb->_mkdir( dir => $rcdir ) or return;

        my $initfile = File::Spec->catfile( $rcdir, 'rc.spamd' );
        $dist->_write_file( $initfile, $script );

        my $conffile
            = File::Spec->catfile( $sysconfdir, 'spamassassin.conf' );
        $dist->_write_file( $conffile, "ENABLED=1\n" );
    }

    return 1;
}

sub _install_docfiles {
    my ( $plugin, $dist ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $wrksrc = $module->status->extract;
    return if !$wrksrc;

    my $docdir = File::Spec->catdir( $pkgdesc->destdir, $pkgdesc->docdir );

    my $readme = $plugin->_readme_slackware_addendum;
    my $readmefile = File::Spec->catfile( $docdir, 'README.SLACKWARE' );
    $dist->_write_file( $readmefile, { append => 1 }, $readme ) or return;

    my @docfiles = qw(
        INSTALL
        ldap
        NOTICE
        PACKAGING
        procmailrc.example
        sample-nonspam.txt
        sample-spam.txt
        sql
        TRADEMARK
        UPGRADE
        USAGE
    );

    my $fail = 0;
    for my $docfile (@docfiles) {
        my $from = File::Spec->catfile( $wrksrc, $docfile );
        if ( -f $from ) {
            if ( !$cb->_copy( file => $from, to => $docdir ) ) {
                ++$fail;
            }
        }
        elsif ( -d $from ) {
            my $cmd = [ '/bin/cp', '-R', $from, $docdir ];
            if ( !$dist->_run_command($cmd) ) {
                ++$fail;
            }
        }
    }

    return ( $fail ? 0 : 1 );
}

sub _readme_slackware_addendum {
    my $plugin = shift;

    return <<'END_README';

Optional modules
----------------

See the INSTALL file for a list of modules that SpamAssassin can optionally
utilize.  Among the optional modules are:

* DBI
* IP::Country
* Mail::SPF
* Net::LDAP

Downloading the SpamAssassin ruleset
------------------------------------

After installing SpamAssassin, you need to download and install the
SpamAssassin ruleset using "sa-update".  See the README file for details.  If
you don't want to run "sa-update" as root, create a dedicated account and a
required directory before you run "sa-update".  Example:

    useradd -u 400 -r -U -c "User for SpamAssassin rule updates" \
        -m -d /var/lib/spamassassin sa-update

    mkdir -m 700 /etc/mail/spamassassin/sa-update-keys
    chown sa-update:sa-update /etc/mail/spamassassin/sa-update-keys

    su sa-update -c /usr/bin/sa-update

If "re2c", which is available at slackbuilds.org, is installed, the ruleset
can be compiled into native code to speed up SpamAssassin's operation:

    su sa-update -c /usr/bin/sa-compile

The compiled rules are loaded if the Rule2XSBody plugin is enabled in
SpamAssassin's configuration.

If you want to keep the ruleset up-to-date, create a weekly or monthly cron
job that runs a shell script like the following one:

    #!/bin/sh
    if su sa-update -c /usr/bin/sa-update; then
        if [ -x /usr/bin/re2c ]; then
            su sa-update -c /usr/bin/sa-compile >/dev/null 2>&1
        fi
        if [ -f /var/run/spamd.pid ]; then
            kill -HUP $(cat /var/run/spamd.pid)
        fi
    fi

Running the SpamAssassin daemon
-------------------------------

To enable spamd, add the execute permissions to the /etc/rc.d/rc.spamd init
script with the chmod command.  Also, make sure that the daemon is enabled in
/etc/spamassassin.conf.

Run spamd without root privileges if per-user configuration files are not
needed.  First create a dedicated account.  Example:

    useradd -u 401 -r -U -c "User for SpamAssassin daemon" \
        -m -d /var/lib/spamd spamd

Then set the following options in /etc/spamassassin.conf:

    OPTIONS="-u spamd -x"

On a busy server, you might have to add options like "--min-children",
"--max-children", "--min-spare" and "--max-spare".  See the spamd manual page
for a complete list of options.

Finally run spamd:

    /etc/rc.d/rc.spamd start
END_README
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::Mail::SpamAssassin - Add an init script and
documentation

=head1 VERSION

This documentation refers to
C<CPANPLUS::Dist::Slackware::Plugin::Mail::SpamAssassin> version 0.01.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success = $plugin->pre_package($dist);

=head1 DESCRIPTION

This plugin adds an init script and additional documentation to the
SpamAssassin package.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if this plugin applies to the given Perl distribution.

=item B<< $plugin->pre_package($dist) >>

Adds an init script and documentation.  Returns true on success.

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

Requires the module C<File::Spec> and the command C<cp>.

=head1 INCOMPATIBILITIES

SpamAssassin packages created with C<CPANPLUS::Dist::Slackware> conflict with
packages created with the SpamAssassin build script available at
L<http://slackbuilds.org/>.

=head1 SEE ALSO

C<CPANPLUS::Dist::Slackware>

=head1 AUTHOR

Andreas Voegele, C<< <andreas at andreasvoegele.com> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs to C<bug-cpanplus-dist-slackware at rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org/>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 Andreas Voegele

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

=cut
