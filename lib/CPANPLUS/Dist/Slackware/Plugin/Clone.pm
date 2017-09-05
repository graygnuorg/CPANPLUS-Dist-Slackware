package CPANPLUS::Dist::Slackware::Plugin::Clone;

use strict;
use warnings;

our $VERSION = '1.025';

use CPANPLUS::Dist::Slackware::Util qw(catfile slurp spurt);

sub available {
    my ( $plugin, $dist ) = @_;

    return ( $dist->parent->package_name eq 'Clone' );
}

sub pre_prepare {
    my ( $plugin, $dist ) = @_;

    # cperl doesn't support the old package delimiter.
    my $fn = catfile( 't', 'dump.pl' );
    if ( -f $fn ) {
        my $code = slurp($fn);
        $code =~ s/sub \s+ main'dump/sub main::dump/xms;
        spurt( $fn, $code ) or return;
    }

    return 1;
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::Clone - Replace old package delimiter

=head1 VERSION

This document describes CPANPLUS::Dist::Slackware::Plugin::Clone version 1.025.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success = $plugin->pre_prepare($dist);

=head1 DESCRIPTION

Replaces C<sub main'dump> by C<sub main::dump> in F<t/dump.pl> as cperl
doesn't support the old package delimiter.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if the Clone module is built.

=item B<< $plugin->pre_prepare($dist) >>

Patches the test suite.

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

CPANPLUS::Dist::Slackware, perlmod

=head1 AUTHOR

Andreas Voegele E<lt>voegelas@cpan.orgE<gt>

=head1 BUGS AND LIMITATIONS

Please report any bugs to C<bug-cpanplus-dist-slackware at rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org/>.

=head1 LICENSE AND COPYRIGHT

Copyright 2017 Andreas Voegele

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

=cut
