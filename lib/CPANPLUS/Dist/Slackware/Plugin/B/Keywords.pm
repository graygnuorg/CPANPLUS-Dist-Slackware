package CPANPLUS::Dist::Slackware::Plugin::B::Keywords;

use strict;
use warnings;

our $VERSION = '1.025';

use File::Spec::Functions qw(catfile);
use CPANPLUS::Dist::Slackware::Util qw(slurp spurt);

sub available {
    my ( $plugin, $dist ) = @_;

    if ( $dist->parent->package_name eq 'B-Keywords' ) {
        eval 'class foo { has $bar }';
        return ( $@ eq '' );
    }
    return;
}

sub pre_prepare {
    my ( $plugin, $dist ) = @_;

    my $module = $dist->parent;
    my $wrksrc = $module->status->extract;
    return if !$wrksrc;

    my $fn = catfile( $wrksrc, 'lib', 'B', 'Keywords.pm' );
    if ( -f $fn ) {
        my $code = slurp($fn);
        $code =~ s/\b (and) \b (\s+) \b (cmp) \b/$1$2class$2$3/xm;
        $code =~ s/\b (gt) \b (\s+) \b (if) \b/$1$2has$2$3/xm;
        $code =~ s/\b (m) \b (\s+) \b (ne) \b/$1$2method$2multi$2$3/xm;
        $code =~ s/\b (qx) \b (\s+) \b (s) \b/$1$2role$2$3/xm;
        spurt( $fn, $code ) or return;
    }

    return 1;
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::B::Keywords - Add cperl keywords

=head1 VERSION

This document describes CPANPLUS::Dist::Slackware::Plugin::B::Keywords version 1.025.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success = $plugin->pre_prepare($dist);

=head1 DESCRIPTION

Adds the keywords "class", "has", "method", "multi" and "role" to L<B::Keywords>.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if L<B::Keywords> is built with cperl.

=item B<< $plugin->pre_prepare($dist) >>

Patches F<lib/B/Keywords.pm>.

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

Requires the module File::Spec.

=head1 INCOMPATIBILITIES

None known.

=head1 SEE ALSO

CPANPLUS::Dist::Slackware

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
