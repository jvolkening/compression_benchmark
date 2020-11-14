#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

params.threads = 4
params.out = 'res.tsv'

environment  = Channel.fromPath("${baseDir}/environment.yml")
docker_tmpfs = '/tmp/scratch'
environment.into {environment_vers;environment_tests}
commands  = Channel.fromPath("${baseDir}/cmds.tsv")

// read in table of input sources and split into input channel
Channel
    .fromPath("${baseDir}/data.tsv")
    .splitCsv(header: true, sep: "\t")
    .set { samples }

process collect_data {

    tag "${row.accession}"

    memory 4.GB 

    input:
    val row from samples

    output:
    file "${row.accession}.il.fq" into test_files mode flatten

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
    zcat ${row.accession}_2.fastq.gz \
    	| fq_clean \
        > cleaned_2.fq
    clumpify.pl \
        --in cleaned_1.fq \
        --in2 cleaned_2.fq \
        --out clumped_1.fq.gz \
        --out2 clumped_2.fq.gz \
        --memory 4g
    fq_interleave \
        --1 clumped_1.fq.gz \
        --2 clumped_2.fq.gz \
        --check \
    | qbin > ${row.accession}.il.fq
    """

}

process get_versions {

    publishDir ".", mode: 'copy',
        pattern: "*.tsv"

    input:
    file env from environment_vers

    output:
    file "versions.tsv"

    """
    #conda env create -n compression -f $env
    #source activate compression

    versions.pl > versions.tsv
    """

}

process run_tests {

    tag "$input"
    cpus "${params.threads}"
    memory 8.GB

    input:
    each file(input) from test_files
    file env from environment_tests
    file cmds from commands

    output:
    file "${input.baseName}.res.tmp" into res_files

    """
    mkdir -p $docker_tmpfs
    sudo mount -t tmpfs -o size=6g tmpfs $docker_tmpfs

    #conda env create -n compression -f $env
    #source activate compression

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
    keepHeader: true
)
