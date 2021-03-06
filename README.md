# CPANPLUS::Dist::Slackware

This CPANPLUS plugin creates [Slackware](http://www.slackware.com/) compatible
packages from Perl distributions.  You can either install the created packages
using the API provided by CPANPLUS or manually with "installpkg".

```
$ cpanp
CPAN Terminal> i Some::Module --format=CPANPLUS::Dist::Slackware

$ cpan2dist --format CPANPLUS::Dist::Slackware Some::Module
$ sudo /sbin/installpkg /tmp/perl-Some-Module-1.0-i586-1_CPANPLUS.tgz
```

## INSTALLATION

To install this module, run the following commands:

```
perl Makefile.PL
make
make test
make install
```

## DEPENDENCIES

Slackware Linux 13.37 and Perl 5.12.3 or better and the sudo command are
required.  The fakeroot command is highly recommended.  You can download a
script that builds fakeroot from [SlackBuilds.org](https://slackbuilds.org/).

## SUPPORT AND DOCUMENTATION

Type "perldoc CPANPLUS::Dist::Slackware" after installation to see the module
usage information.

If you want to hack on the source it might be a good idea to install
[Dist::Zilla](http://dzil.org/) and grab the latest version with git using the
command:

```
git clone https://github.com/graygnuorg/CPANPLUS-Dist-Slackware.git
```

## LICENSE AND COPYRIGHT

Copyright 2012-2020 Andreas Vögele

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See https://dev.perl.org/licenses/ for more information.

