requires 'perl', '5.010';

requires 'CPANPLUS';
requires 'Cwd';
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

on 'develop' => sub {
    requires 'Dist::Zilla';
    requires 'Dist::Zilla::Plugin::Prereqs::FromCPANfile';
    requires 'Dist::Zilla::Test::Perl::Critic';
};
