requires 'perl', '5.012';

requires 'CPANPLUS';
requires 'Cwd';
requires 'ExtUtils::Install';
requires 'File::Find';
requires 'File::Spec';
requires 'File::Temp';
requires 'IO::Compress::Gzip';
requires 'IPC::Cmd';
requires 'Locale::Maketext::Simple';
requires 'Module::CoreList';
requires 'Module::Pluggable';
requires 'Params::Check';
requires 'parent';
requires 'Pod::Find';
requires 'Pod::Simple';
requires 'POSIX';
requires 'Text::Wrap';
requires 'version', '0.77';

on 'test' => sub {
    requires 'Test::More', '0.96';
};
