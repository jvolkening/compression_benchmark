#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

params.test_size = 2000000000
params.threads = 4
params.out = 'res.tsv'

url_cent  = 'ftp://ftp.ccb.jhu.edu/pub/infphilo/centrifuge/data/p_compressed_2018_4_15.tar.gz'
url_words = 'https://raw.githubusercontent.com/dwyl/english-words/master/words.txt'
url_genome = 'ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/vertebrate_mammalian/Mus_musculus/all_assembly_versions/GCF_000001635.26_GRCm38.p6/GCF_000001635.26_GRCm38.p6_genomic.fna.gz'

environment  = Channel.fromPath("${baseDir}/environment.yml")
docker_tmpfs = '/tmp/scratch'
environment.into {environment_vers;environment_tests}


process collect_data {

    output:
    file '*.input' into test_files mode flatten

    """
    # word list to generate random input
    wget -O - $url_words | gen_text.pl ${params.test_size}  > f1.input

    # download FASTQ data from E. coli
    wget -O - $url_genome | zcat \
      | head -c ${params.test_size} > f2.input

    # download binary Centrifuge index data
    wget -O - $url_cent | tar -xzOf - \
      | head -c ${params.test_size} > f3.input
    """

}

process get_versions {

    tag "$input"

    publishDir ".", mode: 'copy',
        pattern: "*.tsv"

    input:
    file env from environment_vers

    output:
    file "versions.tsv"

    """
    conda env create -n compression -f $env
    source activate compression

    versions.pl > versions.tsv
    """

}

process run_tests {

    tag "$input"
    cpus "${params.threads}"
    memory '8 GB'

    input:
    each file(input) from test_files
    file env from environment_tests

    output:
    file "${input.baseName}.res.tmp" into res_files

    """
    mkdir -p $docker_tmpfs
    mount -t tmpfs -o size=6g tmpfs $docker_tmpfs

    conda env create -n compression -f $env
    source activate compression

    bm.pl $input $docker_tmpfs ${params.threads} > ${input.baseName}.res.tmp
    """

}

res_files.collectFile(
    name: params.out,
    storeDir: '.',
    keepHeader: true
)
