FROM continuumio/miniconda3:latest

MAINTAINER Jeremy Volkening <jeremy.volkening@base2bio.com>

# Install dependencies
WORKDIR /nf
COPY environment.yml .

# procps provides 'ps' for nextflow
RUN apt-get update && apt-get install -y \
      autoconf \
      automake \
      build-essential \
      plzip \
      procps \
      vim \
      zlib1g-dev \
    && conda env create -f environment.yml \
    # install QUIP from GitHub
    && git clone git://github.com/dcjones/quip.git \
    && cd quip \
    && autoreconf -i \
    && ./configure \
    && make install \
    # final cleanup
    && rm -rf /opt/conda/pkgs/* && rm -rf /nf


# Create regular user
RUN useradd -m -U nf
USER nf
WORKDIR /home/nf/

# activate the conda environment
ENV PATH /opt/conda/envs/compression/bin:$PATH

# set entrypoints (both are needed)
CMD [ "/bin/bash" ]
