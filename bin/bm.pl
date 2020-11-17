#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

use Digest::MD5;
use File::Basename qw/basename/;
use File::Copy qw/copy/;
use File::Temp;
use Getopt::Long;
use Text::CSV qw/csv/;

my $fn_in;
my $fn_cmds;
my $dir_tmp = '/tmp';
my $threads = 8;

GetOptions(
    'in=s'      => \$fn_in,
    'cmds=s'    => \$fn_cmds,
    'tmp=s'     => \$dir_tmp,
    'threads=i' => \$threads,
);

# read file once into RAM-based storage
# currently AWS Batch docker /dev/shm too small,
# so either need to create separate tmpfs or just read/write to disk
my $fn_in_mem = join '/', $dir_tmp, basename($fn_in);
copy $fn_in, $fn_in_mem;
my $fsize = -s $fn_in_mem;

# get input MD5
my $hasher = Digest::MD5->new;
open my $tmp, '<:raw', $fn_in_mem;
$hasher->addfile($tmp);
close $tmp;
my $md5_orig = $hasher->hexdigest;

my $cmds = csv(
    in             => $fn_cmds,
    headers        => 'auto',
    sep_char       => "\t",
    quote_char     => undef,
    auto_diag      => 1,
    empty_is_undef => 0,
);

say join "\t", qw/
    file
    program
    config
    c_size
    u_size
    c_time
    d_time
    c_mem
    d_mem
    c_cpu
    d_cpu
    is_lossless
/;

for my $cmd (@{ $cmds }) {

    my $tmp_out_mem  = File::Temp->new(DIR => $dir_tmp, UNLINK => 1);
    my $tmp_uout_mem  = File::Temp->new(DIR => $dir_tmp, UNLINK => 1);

    my $time_bin = `which time`;
    chomp $time_bin;
    my $time = "$time_bin -o /dev/fd/3 -f \"%E\\t%M\\t%P\"";
   
    my $comp_cmd_mem  = "$time $cmd->{command}";
    $comp_cmd_mem =~ s/TAGS/$cmd->{c_tags}/;
    $comp_cmd_mem =~ s/IN/$fn_in_mem/;
    $comp_cmd_mem =~ s/OUT/$tmp_out_mem/;
    $comp_cmd_mem =~ s/THREADS/$threads/;

    my $decomp_cmd_mem  = "$time $cmd->{command}";
    $decomp_cmd_mem =~ s/TAGS/$cmd->{d_tags}/;
    $decomp_cmd_mem =~ s/IN/$tmp_out_mem/;
    #$decomp_cmd_mem =~ s/OUT/\/dev\/null/;
    $decomp_cmd_mem =~ s/OUT/$tmp_uout_mem/;
    $decomp_cmd_mem =~ s/THREADS/$threads/;

    my @cmem  = run( $comp_cmd_mem );
    my @dmem  = run( $decomp_cmd_mem );

    # get output MD5
    my $hasher = Digest::MD5->new;
    open my $tmp, '<:raw', $tmp_uout_mem;
    $hasher->addfile($tmp);
    close $tmp;
    my $md5_out = $hasher->hexdigest;
    my $lossless = $md5_out eq $md5_orig ? 1 : 0;

    say join "\t",
        basename($fn_in),
        $cmd->{group},
        $cmd->{label},
        (-s $tmp_out_mem),
        $fsize,
        $cmem[0],
        $dmem[0],
        $cmem[1],
        $dmem[1],
        $cmem[2],
        $dmem[2],
	$lossless,
    ;

} 

unlink $fn_in_mem;

sub run {

    my ($cmd) = @_;

    my $ret = `$cmd`;
    if ($?) {
        die "$cmd failed: $!\n";
    }
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
    return ($s, $mem_mb, $cpu);

}
