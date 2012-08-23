package CPANPLUS::Dist::Slackware::Plugin::Alien::wxWidgets;

use strict;
use warnings;

our $VERSION = '1.010';

sub available {
    my ( $plugin, $dist ) = @_;
    return ( $dist->parent->package_name eq 'Alien-wxWidgets' );
}

sub pre_prepare {
    my ( $plugin, $dist ) = @_;
    $ENV{AWX_URL} = 'http://prdownloads.sourceforge.net/wxwindows';
    return 1;
}

sub post_prepare {
    my ( $plugin, $dist ) = @_;
    delete $ENV{AWX_URL};
    return 1;
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::Alien::wxWidgets - Configure
Alien::wxWidgets

=head1 VERSION

This documentation refers to
C<CPANPLUS::Dist::Slackware::Plugin::Alien::wxWidgets> version 1.010.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success = $plugin->pre_prepare($dist);
    $success = $plugin->post_prepare($dist);

=head1 DESCRIPTION

Make sure that Alien::wxWidgets does not check for wxWidgets installations
that were compiled using Alien::wxWidgets.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if this plugin applies to the given Perl distribution.

=item B<< $plugin->pre_prepare($dist) >>

Sets C<$ENV{AWX_URL}>, which causes Alien::wxWidgets to ignore wxWidgets
installations that were compiled using Alien::wxWidgets.

=item B<< $plugin->post_prepare($dist) >>

Unsets C<$ENV{AWX_URL}>.

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None known.

=head1 SEE ALSO

C<CPANPLUS::Dist::Slackware>

=head1 AUTHOR

Andreas Voegele  C<< <VOEGELAS@cpan.org> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs to C<bug-cpanplus-dist-slackware at rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org/>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 Andreas Voegele

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

=cut
