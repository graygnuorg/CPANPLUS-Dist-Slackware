package CPANPLUS::Dist::Slackware::Plugin::YAML::LibYAML;

use strict;
use warnings;

our $VERSION = '1.020';

use File::Spec qw();

sub available {
    my ( $plugin, $dist ) = @_;
    return ( $dist->parent->package_name eq 'YAML-LibYAML' );
}

sub pre_prepare {
    my ( $plugin, $dist ) = @_;

    my $module = $dist->parent;
    my $cb     = $module->parent;

    my $wrksrc = $module->status->extract;
    return if !$wrksrc;

    # See L<https://rt.cpan.org/Ticket/Display.html?id=74238>.
    my $filename = File::Spec->catfile( $wrksrc, 'LibYAML', 'LibYAML.c' );
    if ( -f $filename ) {
        $dist->_unlink($filename) or return;
    }

    # See L<https://rt.cpan.org/Ticket/Display.html?id=46507>.
    $filename = File::Spec->catfile( $wrksrc, 'LibYAML', 'perl_libyaml.c' );
    if ( -f $filename ) {
        my $code = $dist->_read_file($filename);
        if ( $code =~ /croak\(\s*loader_error_msg/xms ) {
            $code =~ s/croak\((\s*loader_error_msg)/croak("%s",$1/gxms;
            $cb->_move( file => $filename, to => "$filename.orig" ) or return;
            $dist->_write_file( $filename, $code ) or return;
        }
    }

    return 1;
}

1;
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::YAML::LibYAML - Patch YAML::LibYAML if necessary

=head1 VERSION

This document describes CPANPLUS::Dist::Slackware::Plugin::YAML::LibYAML version 1.020.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success = $plugin->pre_prepare($dist);

=head1 DESCRIPTION

If YAML::LibYAML is built a second time the build fails since
F<LibYAML/Makefile.PL> adds F<LibYAML.o> twice to the list of object files.
Reported as bug #74238 at L<http://rt.cpan.org/>.  Compiling
F<LibYAML/perl_libyaml.c> with C<-Werror=format-security> fails.  Reported as
bug #46507.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if this plugin applies to the given Perl distribution.

=item B<< $plugin->pre_prepare($dist) >>

Remove F<LibYAML/LibYAML.c> and patch F<LibYAML/perl_libyaml.c>.

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

Copyright 2012-2014 Andreas Voegele

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

=cut
