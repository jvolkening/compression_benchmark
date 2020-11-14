#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

say join "\t",
    'program',
    'version',
;

for my $bin (qw/
    gzip
    lbzip2
    lz4
    pigz
    pzstd
    zstd
    xz
    bsc
/) {
    my $res = `$bin --version 2>&1`;
    if ($res =~ /(\d+\.([\d\.]+)?\d)/) {
        say join "\t", $bin, $1;
    }
    else {
        die "Version parsing failed for $bin";
    }
}
