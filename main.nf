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


process collect_data {

    cpus 1
    memory '2 GB'

    output:
    file "*.input" into test_files mode flatten

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

process run_tests {

    tag "$input"
    echo true
    cpus "${params.threads}"
    memory '4 GB'

    input:
    each file(input) from test_files
    file env from environment

    output:
    file "${input.baseName}.res.tsv" into res_files

    """
    conda env create -n compression -f $env
    source activate compression
    bm.pl $input ${params.threads} > ${input.baseName}.res.tsv
    """

}

res_files.collectFile(
    name: params.out,
    storeDir: '.',
    keepHeader: true
)
