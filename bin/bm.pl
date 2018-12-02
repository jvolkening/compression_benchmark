#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

use File::Basename qw/basename/;
use File::Copy qw/copy/;
use File::Temp;

my $fn_in = $ARGV[0];

my $threads = $ARGV[1] // 8;

# read file once into RAM-based storage
my $fn_in_mem = "/dev/shm/" . basename($fn_in);
copy $fn_in, $fn_in_mem;

my $cmds = {

    # pigz, single thread
    "pigz_l9_t1" => "pigz -p 1 -9",
    "pigz_l1_t1" => "pigz -p 1 -1",

    # pigz, multithread
    "pigz_l9_t$threads" => "pigz -p $threads -9",
    "pigz_l1_t$threads" => "pigz -p $threads -1",

    # gzip, single thread
    "gzip_l9_t1" => "gzip -9",
    "gzip_l1_t1" => "gzip -1",

    # lz4, single thread
    "lz4_l9_t1" => "lz4 -9",
    "lz4_l1_t1" => "lz4 -1",

    # zstd, single thread
    "zstd_l19_t1" => "zstd -T1 -19",
    "zstd_l1_t1"  => "zstd -T1 -1",

    # zstd, multithread
    "zstd_l19_t$threads" => "zstd -T$threads -19",
    "zstd_l1_t$threads"  => "zstd -T$threads -1",

    # pzstd, single thread
    "pzstd_l19_t1" => "pzstd -p 1 -19",
    "pzstd_l1_t1"  => "pzstd -p 1 -1",

    # pzstd, multi thread
    "pzstd_l19_t$threads" => "pzstd -p $threads -19",
    "pzstd_l1_t$threads"  => "pzstd -p $threads -1",

    # lbzip2, single thread
    "lbzip2_l9_t1" => "lbzip2 -n 1 -9",
    "lbzip2_l1_t1" => "lbzip2 -n 1 -1",

    # lbzip2, multi thread
    "lbzip2_l9_t$threads" => "lbzip2 -n $threads -9",
    "lbzip2_l1_t$threads" => "lbzip2 -n $threads -1",

};

say join "\t", qw/
    file
    config
    c_time_mem
    d_time_mem
    ratio
    c_mem
    d_mem
    c_cpu
    d_cpu
/;

for my $conf (keys %$cmds) {

    say STDERR "Running $conf";

    my $tmp_out_mem  = File::Temp->new(DIR => '/dev/shm', UNLINK => 1);
    my $tmp_out_dec  = File::Temp->new(DIR => '/tmp', UNLINK => 1);

    my $time_bin = `which time`;
    chomp $time_bin;
    my $time = "$time_bin -f \"%E\\t%M\\t%P\"";
    
    my $comp_cmd_mem  = "$time $cmds->{$conf} -q -k -c $fn_in_mem 2>&1 1> $tmp_out_mem";

    my $decomp_cmd_mem  = "$time $cmds->{$conf} -q -d -c $tmp_out_mem 2>&1 1> /dev/null";

    say STDERR "\t1";
    my @cmem  = run( $comp_cmd_mem );
    say STDERR "\t2";
    my @dmem  = run( $decomp_cmd_mem );

    say join "\t",
        basename($fn_in),
        $conf,
        $cmem[0],
        $dmem[0],
        (-s $tmp_out_mem)/(-s $fn_in),
        $cmem[1],
        $dmem[1],
        $cmem[2],
        $dmem[2],
    ;

} 

unlink $fn_in_mem;

sub run {

    my ($cmd) = @_;
    my $ret = `$cmd`;
    chomp $ret;
    my ($time, $mem_kb, $cpu) = split "\t", $ret;
    $cpu =~ s/\%$//;
    my $mem_mb = sprintf "%0.0f", $mem_kb/1024;
    my @units = split ':', $time;
    my $s = pop(@units) + 0;
    $s += pop(@units)*60
        if (@units);
    $s += pop(@units)*60*60
        if (@units);
    #my ($hr, $min, $sec) = ($time =~ /(?:(\d+):)(?:(\d+):)(\d(?:\.\d+))/);
    #my $e = $sec + $min*60 + $hr*60*60;
    return ($s, $mem_mb, $cpu);

}
