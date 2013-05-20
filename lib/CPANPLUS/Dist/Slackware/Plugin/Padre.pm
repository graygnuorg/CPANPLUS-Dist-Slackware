package CPANPLUS::Dist::Slackware::Plugin::Padre;

use utf8;
use strict;
use warnings;

use File::Spec qw();

our $VERSION = '1.011';

sub available {
    my ( $plugin, $dist ) = @_;
    return ( $dist->parent->package_name eq 'Padre' );
}

sub pre_package {
    my ( $plugin, $dist ) = @_;

    $plugin->_install_icon($dist)        or return;
    $plugin->_write_desktop_entry($dist) or return;
    $plugin->_write_doinst_sh($dist)     or return;

    return 1;
}

sub _install_icon {
    my ( $plugin, $dist ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $destdir = $pkgdesc->destdir;

    # According to freedesktop.org's Icon Theme Specification applications are
    # supposed to provide at least a 48x48 icon.

    my $pngdata = q{};
    while (<DATA>) {
        last if /^__END__/;
        for (split) {
            $pngdata .= pack 'H*', $_;
        }
    }

    my $icondir
        = File::Spec->catdir( $destdir, 'usr', 'share', 'icons', 'hicolor',
        '48x48', 'apps' );
    $cb->_mkdir( dir => $icondir ) or return;

    my $iconfile = File::Spec->catfile( $icondir, 'padre.png' );
    return 1 if -f $iconfile;
    return $dist->_write_file( $iconfile, { binmode => ':raw' }, $pngdata );
}

sub _write_desktop_entry {
    my ( $plugin, $dist ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $destdir = $pkgdesc->destdir;

    my $appdir
        = File::Spec->catdir( $destdir, 'usr', 'share', 'applications' );
    $cb->_mkdir( dir => $appdir ) or return;
    my $filename = File::Spec->catfile( $appdir, 'padre.desktop' );
    return 1 if -f $filename;
    my $entry = <<'END_ENTRY';
[Desktop Entry]
Name=Padre
GenericName=IDE for Perl Development
GenericName[de]=Perl-Entwicklungsumgebung
GenericName[es]=IDE para desarrollo en Perl
GenericName[fr]=EDI pour le développement en Perl
GenericName[it]=Ambiente integrato per lo sviluppo in Perl
GenericName[nl]=IDE voor Perl ontwikkeling
Comment=Perl Application Development and Refactoring Environment
Type=Application
Exec=padre %F
Icon=padre
Categories=Development;IDE
MimeType=application/x-perl
Terminal=false
END_ENTRY
    return $dist->_write_file( $filename, { binmode => ':utf8' }, $entry );
}

sub _write_doinst_sh {
    my ( $plugin, $dist ) = @_;

    my $status  = $dist->status;
    my $module  = $dist->parent;
    my $cb      = $module->parent;
    my $pkgdesc = $status->_pkgdesc;

    my $destdir = $pkgdesc->destdir;

    my $script = <<'END_SCRIPT';
if [ -x /usr/bin/update-desktop-database ]; then
    /usr/bin/update-desktop-database -q usr/share/applications >/dev/null 2>&1
fi
if [ -e usr/share/icons/hicolor/icon-theme.cache ]; then
    if [ -x /usr/bin/gtk-update-icon-cache ]; then
        /usr/bin/gtk-update-icon-cache usr/share/icons/hicolor >/dev/null 2>&1
    fi
fi
END_SCRIPT
    my $installdir = File::Spec->catdir( $destdir, 'install' );
    my $doinstfile = File::Spec->catfile( $installdir, 'doinst.sh' );
    return $dist->_write_file( $doinstfile, { append => 1 }, $script );
}

1;
__DATA__
8950 4e47 0d0a 1a0a 0000 000d 4948 4452 0000 0030 0000 0030 0803 0000 0060
dc09 b500 0002 ee50 4c54 4500 0000 4957 7642 485f 424e 6b65 7c92 7796 a900
010a 0000 0003 0b25 5867 782c 496b 0a19 3b05 092d 4c71 8a63 808e 0504 2b14
243b 0c1c 3342 5166 767b 8002 0314 0607 3509 1758 1224 9814 4dc7 0a76 cb09
57a5 0a22 636c 7e93 111d 3203 041b 3637 3e11 1d2a 1021 8615 52d9 0c87 e705
a2ea 05ab f209 a3f5 099c f20a 2c74 0614 2a7c 828c 394d 740e 287d 1556 d71b
59f2 162d c50f 1a81 0c03 5b04 0324 424e 643c 4c62 0809 4313 1698 1746 d615
63ea 1176 e903 b3f4 09ab f30a 82d7 0724 5623 334b 051b 4511 5bcd 1962 f119
4dea 1527 b813 0d91 1005 6f09 0542 0f0e 7414 1ba7 1839 d816 3bca 1165 da02
b4fa 079d e906 3c74 172a 3f26 3856 086f bd16 6cf2 0d1b 750e 0767 120a 880a
224a 0917 4804 a2e4 03ab eb0c 75d9 03ba fb0b 3987 4352 6d06 2c5c 01ab e316
35c3 0f3f b00b 75d4 1462 e316 3bc5 0710 4416 2a64 0c8c f008 a1ee 06a4 f406
9be3 092c 6c4f 576e 6a71 8204 9bdd 0a84 dc0d 6cd5 1476 f218 4ae3 163a 8718
43e1 0999 eb06 c8fb 0613 3b7f 8c9c 0c20 4608 88c8 0892 e317 66f1 196d f717
4ce0 0b1c 6913 35b7 1082 ee02 b3e9 09b6 f909 cbfa 08ac f90d 49a5 232d 4236
3c55 0756 9703 baf2 01a8 db1c 64fc 1a6a f906 aaf9 05c3 fb07 1648 808a 9a0c
1644 1758 e816 1f5f 0a93 eb08 bcf9 1524 470e 7be5 1337 a40d 79dd 0bac ef13
6dea 3b55 6c58 7e94 0898 e20a b9f4 09c4 f90f 3a96 0843 7c0f 5dd1 4a80 a80a
276b 04c1 f408 cbf5 0bd7 fb0e e0fd 0d2a 8741 5673 1144 bc75 8ea7 3285 d50b
b2f5 0ac2 f611 6be3 2365 a280 aebc 59b4 cd4e afcb 39b2 d706 6b96 0564 8a09
6ab3 0b47 9511 62b7 3197 d549 aad5 38ab d873 95b1 2b49 750c 2474 1634 4b2e
5b86 094a 870c 1a60 1425 aa4b 6384 79a7 d11b 6ec8 135c dc17 32cc 0b0b 5718
34cc 0b0b 580d 5abc 104e b602 0a1b 1434 7110 0777 0a7c d60a 2966 07c8 f332
3643 1424 300f 1d7d 1032 9719 2742 7879 8105 335a 6f83 960b 064f 7b7e 892d
4275 066c ac59 5c6b 525f 7330 465d 3f41 4e6d 6e76 0e14 6f1a 2a4f 1119 8707
7ebe 068f d419 2a3e 5270 8f70 7f8f 0781 d204 284f 485b 6e38 75b0 6474 8609
235c 080f 4b24 4a7f 495d 7ada e17e 9500 0000 0174 524e 5300 40e6 d866 0000
0009 7048 5973 0000 0048 0000 0048 0046 c96b 3e00 0004 cd49 4441 5448 c7e5
9469 7413 5518 86e3 36b7 40b4 a2a1 8522 9176 4a42 b564 2842 b682 854c 2849
4394 c54a 4280 a18b 24a4 1292 3249 8534 6d66 9a22 cd04 2b94 d494 0493 d6a5
9d14 b5d4 0501 4540 2128 a5b2 49a5 b8e1 be8b bbfe 73ba d149 a89e e36f ee8f
3967 9ef3 3e73 b7ef 1b0e e71a 1dd7 5d7f c38d ff23 7e13 04fa 46d2 a8ff c88c
1ec3 1d73 f3d0 cb2d fd79 2899 7beb bf28 a3c6 f627 c06d 83ef b703 c01b 9792
3a7e 42da c4d1 23c4 ef98 94cc 1f10 ee1c 4293 79e9 1970 e614 8140 3835 ebae
c4fc ddd9 d344 c8f4 9c9c 1900 dc33 c466 42b3 c412 a90c 96e7 ce9e 9395 90bf
376f ee3c 05aa 9c9f 930f a061 0ab8 0b54 a8ba 4023 5ca8 bdef feb8 fca2 bcc5
4b24 4b1f 2854 2ec8 871e 1cc6 cbd2 5562 44a4 d32f 8717 1a56 2c62 e557 aec2
96af 2e2a 2e51 2844 a50f b1f8 9af4 82d5 6a91 718a 49b8 d660 2e7b f80a 5fb7
cab2 7eae d5a4 b349 cb25 a529 2c61 432a 3e4f 2492 d9ed 4283 c330 a1e2 9121
be71 9309 d6e9 cdce 4a97 cd55 55cd 16dc 3285 6809 6126 0963 8da7 76f3 a383
784b 9d9c f4ea b514 4528 1452 cd52 9630 5543 d86c bead 46fd 6384 adb6 5ef8
f8c0 056e db3e a5de 21b4 eb2c 84cb d720 2d59 c112 76cc b3f9 6d3e 1f81 191a
6595 c285 694f 0c9c 509d c123 08e8 29a3 cfb7 d5ef 249a 5842 cace 4cc2 6583
cdba 2059 5b52 150a a4ec 62e0 9379 96b5 8150 a696 b2c0 aead b6b0 6e33 4b28
33d6 3446 22c1 6050 deec 6886 25e3 5b92 1898 f414 fc74 404f 5294 2eec b79b
e4c1 b467 8685 6703 726f a4b5 cd43 d3d1 6894 0eb6 57f3 7773 76f3 db9f 0bd2
74bd 97c4 30ad dd84 6175 cfb3 a678 a1a6 deeb 95e7 d676 44f6 ece9 3076 6643
101f e24d 7546 3c9e e6a0 d6e9 3463 983e f3c5 b812 78e9 e557 f66e 7a75 dfbe
fd3b 6532 5946 3a8f a94d 7e53 a711 5e5c 77e0 c06b af1f dcfb c6c1 4389 5579
e8f0 c423 478a ac70 6e87 50b3 acaf a5f8 47ac b0ac 60e9 2c7e d69b 6f8d 50f5
470f ac37 da83 6d34 4d7b 1a05 d60a 4638 b65c 4b62 cece 06dc 1d9b 9e72 3c21
fef6 3b01 7f98 2249 d2db ba87 8e7a 02c7 18a1 1dd6 85cd e1d0 091c ef42 63d3
37c4 0b4d 527f 10a3 c214 45b6 31e7 2468 38d9 3783 c66c ab94 2aba 5154 adee
12bf bb83 9ddf 71aa b686 f413 041c b67b a2d1 0ee3 e933 7d7b 48f3 6b6d e56a
9552 a542 1034 9653 c112 e6d8 053a 5d58 6bc6 484f 948e 08ed 67fb 5bb8 4c6b
f72f c151 a512 4590 98f2 5c32 4b98 f81e 5392 5e2f 49d2 519a 6ef6 1473 0194
0481 8a09 cca4 325c ddd5 85ab d5aa f933 58c2 f9c5 7a7f a4d5 82b5 f544 5aa3
9e8e 1500 4c3e ccac aa05 7689 1a42 e56a 0451 2b70 94dd 7167 4f75 9ac8 d99d
cc9e c946 ba71 3d17 80f7 3917 00e0 8664 221c 4750 4485 6684 dcc7 d897 d66b
d559 4b03 ccb1 523d 8edc 1666 fdc7 395b 98e7 4569 00ef 4694 4ab1 4a6c 3d75
987d 4cd5 2592 180a 7b49 8aa4 3bf6 338b f980 6193 9829 dc9a 8618 82a3 8562
a5b2 e5c3 3861 b55b ac0a 9218 d5e6 b17c 04c0 993e f671 1273 1792 40b7 0a9f
965a 1813 7f72 892d 7c9a ea2e 7433 b5ef a5bd 9ff1 00f4 793f fc02 02bc 229b
1429 0db9 e7f7 a2db e36e 7a5d 9358 69d5 635e 9ad6 31df fd72 90ee 6216 5509
3774 5769 c4e7 545f c509 5f7f 8322 3049 3aa2 8ea3 008c bd82 99bf f645 98c0
bb09 7761 61bc c0f9 f63b 492e d643 d3df 2701 d6df f5d2 1930 6ebc 5daa 3e31
4d9c bf32 a15e d79c d61b ea1d 3fe4 811f d974 db05 e864 b1c9 555e 92fd 5362
3f5c 5eb5 5f20 f8f9 17de af09 7c66 72b6 bfb2 a077 f708 2df4 5bd9 f98a 8d97
afc2 bf8f f9a3 facf bf38 238e e323 e395 7f73 aef9 f10f 10c6 aec1 afdf 382c
0000 0025 7445 5874 6461 7465 3a63 7265 6174 6500 3230 3132 2d30 312d 3239
5431 323a 3530 3a33 342b 3031 3a30 30c4 f434 e400 0000 2574 4558 7464 6174
653a 6d6f 6469 6679 0032 3031 312d 3038 2d31 3454 3132 3a35 393a 3231 2b30
323a 3030 7870 0e05 0000 0000 4945 4e44 ae42 6082
__END__

=head1 NAME

CPANPLUS::Dist::Slackware::Plugin::Padre - Install a desktop entry and an icon

=head1 VERSION

This documentation refers to
C<CPANPLUS::Dist::Slackware::Plugin::Padre> version 1.011.

=head1 SYNOPSIS

    $is_available = $plugin->available($dist);
    $success = $plugin->pre_package($dist);

=head1 DESCRIPTION

This plugin installs a desktop entry and an icon so that Padre can be launched
easily from desktop environments like KDE.

=head1 SUBROUTINES/METHODS

=over 4

=item B<< $plugin->available($dist) >>

Returns true if this plugin applies to the given Perl distribution.

=item B<< $plugin->pre_package($dist) >>

Installs a desktop entry and an icon.

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

Andreas Voegele  C<< <voegelas@cpan.org> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs to C<bug-cpanplus-dist-slackware at rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org/>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, 2013 Andreas Voegele

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://dev.perl.org/licenses/ for more information.

The included application icon is based on a photo created by Gregory Phillips.
It was colour-enhanced and modified for transparent icon use by Adam Kennedy.
The icon is licensed under the Creative Commons Attribution-Share Alike 3.0
license.  You are free to copy, distribute, transmit and adapt the work under
the following conditions: You must attribute the work in the manner specified
by the author or licensor (but not in any way that suggests that they endorse
you or your use of the work).  If you alter, transform, or build upon this
work, you may distribute the resulting work only under the same or similar
license to this one.  Alternatively, permission is granted to copy, distribute
and/or modify the icon under the terms of the GNU Free Documentation License,
Version 1.2 or any later version published by the Free Software Foundation;
with no Invariant Sections, no Front-Cover Texts, and no Back-Cover Texts.

See http://creativecommons.org/licenses/by-sa/3.0/ and
http://www.gnu.org/licenses/fdl.html for more information.

=cut
