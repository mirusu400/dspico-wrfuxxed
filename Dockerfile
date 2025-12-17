# -----------------------------------------------------------------------------
# Dockerfile for building dspico-wrfuxxed
# docker build --platform linux/amd64 -t dspico-wrfuxxed-builder .
# docker run --rm --platform linux/amd64 -v "$(pwd):/workdir" dspico-wrfuxxed-builder
# -----------------------------------------------------------------------------
    FROM --platform=linux/amd64 skylyrac/blocksds:slim-v1.13.1

    WORKDIR /workdir
    
    RUN apt-get update && apt-get install -y \
        git \
        make \
        && rm -rf /var/lib/apt/lists/*
    
    COPY . .
    
    CMD ["sh", "-c", "make clean && make all"]
    