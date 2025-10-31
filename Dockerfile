# ------------------------------------------------------------
# Dockerfile for building the "Docker and Kubernetes Security" book
# ------------------------------------------------------------
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Pandoc + full LaTeX toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    pandoc \
    texlive \
    texlive-xetex \
    latexmk \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Copy fonts and refresh font cache
COPY fonts /usr/local/share/fonts
RUN fc-cache -f

# Set working directory (to be mounted as volume)
WORKDIR /book

# Create an output directory so the mount can write there
RUN mkdir -p output

# Default command opens a shell so you can run:
#   make pdf   or   make epub
CMD ["/bin/bash"]
