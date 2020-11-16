FROM continuumio/miniconda3:latest

MAINTAINER Jeremy Volkening <jeremy.volkening@base2bio.com>

# Install dependencies
WORKDIR /nf
COPY environment.yml .

# procps provides 'ps' for nextflow
RUN apt-get update && apt-get install -y \
      procps \
      vim \
    && conda env create -f environment.yml \
    && rm -rf /opt/conda/pkgs/* && rm -rf /nf

# Create regular user
RUN useradd -m -U nf
USER nf
WORKDIR /home/nf/

# activate the conda environment
ENV PATH /opt/conda/envs/nf/bin:$PATH

# set entrypoints (both are needed)
CMD [ "/bin/bash" ]
