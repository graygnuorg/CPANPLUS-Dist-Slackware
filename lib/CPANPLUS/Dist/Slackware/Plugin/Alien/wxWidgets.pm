package CPANPLUS::Dist::Slackware::Plugin::Alien::wxWidgets;

use strict;
use warnings;

use File::Spec qw();

our $VERSION = '0.01';

sub available {
    my ( $plugin, $dist ) = @_;
    return ( $dist->parent->package_name eq 'Alien-wxWidgets' );
}

sub pre_prepare {
    my ( $plugin, $dist ) = @_;

    my $module = $dist->parent;
    my $cb     = $module->parent;

    my $wrksrc = $module->status->extract;
    if ( !$wrksrc ) {
        return;
    }

    my $filename = File::Spec->catfile( $wrksrc, 'Build.PL' );
    if ( !-f $filename ) {
        return 1;
    }

    my $evil_eval = qr{
        ^my \h* \$ok \h* = \h* eval \h* \{
            .+?
        ^\};
    }xms;

    my $build_pl = $dist->_read_file($filename);
    return if !defined $build_pl;
    if ( $build_pl =~ s/$evil_eval/my \$ok;/xms ) {
        $cb->_move( file => $filename, to => "$filename.orig" ) or return;
        $dist->_write_file( $filename, $build_pl ) or return;
    }

    return 1;
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::Alien::wxWidgets - Fix the Alien::wxWidgets
build

=head1 VERSION

This documentation refers to
C<CPANPLUS::Dist::Slackware::Plugin::Alien::wxWidgets> version 0.01.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success      = $plugin->pre_prepare($dist);

=head1 DESCRIPTION

There's a pointless optimization in the Alien::wxWidgets module's F<Build.PL>
that tries to detect whether the wxWidgets toolkit has already been built with
Alien::wxWidgets.  Unfortunately, the wxWidgets libraries won't be put into
the Slackware package because of this optimization if the package is rebuilt.
This plugin patches the F<Build.PL> file accordingly.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if this plugin applies to the given distribution.

=item B<< $plugin->pre_prepare($dist) >>

Patches F<Build.PL>.  Returns true on success.

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

Requires the module C<File::Spec>.

=head1 INCOMPATIBILITIES

None known.

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
