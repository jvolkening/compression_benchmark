#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

my $outsize = $ARGV[0];

my @words;

while (my $line = <STDIN>) {
    chomp $line;
    push @words, $line;
}

my $s = 0;
my $l = scalar @words;
while ($s <= $outsize) {
    my $l_sent = int(rand(40)) + 10;
    my $sent = join ' ', map {
        $words[ int(rand($l)) ]
    } 1..$l_sent;
    $s += length($sent) + 1;
    say $sent;
}
