#!/usr/bin/env perl

use strict;
use warnings;
use Cwd;

$ENV{PERL5LIB} = '';

my $cwd = getcwd;

my $base = '/software/vertres';

# update the checkouts that PATH and PERL5LIB point to
foreach my $repo ("$base/bin-external", "$base/codebase", "$base/vrpipe/master") {
    chdir($repo);
    warn "\nupdating $repo\n";
    system("umask 002; git checkout .; git pull; umask 007");
}

chdir($cwd);

exit;

