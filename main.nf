#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

params.threads = 4
params.out = 'res.tsv'
params.meta_out = 'meta.tsv'

docker_tmpfs = '/dev/shm/scratch'
commands  = Channel.fromPath("${baseDir}/cmds.tsv")

// read in table of input sources and split into input channel
Channel
    .fromPath("${baseDir}/data.tsv")
    .splitCsv(header: true, sep: "\t")
    .set { samples }

process collect_data {

    tag "${row.accession}"

    memory 6.GB 

    input:
    val row from samples

    output:
    file "${row.accession}.il.fq" into test_files
    file "${row.accession}.meta.tmp" into meta_files

    script:
    """
    fastq-dump \
        --gzip \
        --split-files \
        --skip-technical \
        --clip \
        --dumpbase \
        --outdir . \
        ${row.accession}
    zcat ${row.accession}_1.fastq.gz \
    	| fq_clean \
        > cleaned_1.fq
    unlink ${row.accession}_1.fastq.gz
    zcat ${row.accession}_2.fastq.gz \
    	| fq_clean \
        > cleaned_2.fq
    unlink ${row.accession}_2.fastq.gz
    clumpify.pl \
        --in cleaned_1.fq \
        --in2 cleaned_2.fq \
        --out clumped_1.fq.gz \
        --out2 clumped_2.fq.gz \
        --memory 4g
    unlink cleaned_1.fq
    unlink cleaned_2.fq
    fq_interleave \
        --1 clumped_1.fq.gz \
        --2 clumped_2.fq.gz \
        --check \
    | qbin > ${row.accession}.il.fq
    unlink clumped_1.fq.gz
    unlink clumped_2.fq.gz
    seq_stats \
        ${row.accession} \
        < ${row.accession}.il.fq \
        > ${row.accession}.meta.tmp
    """

}

process get_versions {

    publishDir ".", mode: 'copy',
        pattern: "*.tsv"

    output:
    file "versions.tsv"

    script:
    """
    versions.pl > versions.tsv
    """

}

process run_tests {

    tag "$input"
    cpus "${params.threads}"
    memory { input.size() < 2*Math.pow(1024,3) ? 8.GB : 30.GB }
    containerOptions "--shm-size 6g"
    cache false

    input:
    each file(input) from test_files
    file cmds from commands

    output:
    file "${input.baseName}.res.tmp" into res_files

    script:
    """
    mkdir -p $docker_tmpfs

    bm.pl \
        --in $input \
        --cmds $cmds \
        --tmp $docker_tmpfs \
        --threads ${task.cpus} \
        > ${input.baseName}.res.tmp
    """

}

res_files.collectFile(
    name: params.out,
    storeDir: '.',
    keepHeader: true,
    sort: false
)
meta_files.collectFile(
    name: params.meta_out,
    storeDir: '.',
    keepHeader: true
)
