FROM rocker/r-ver:4.0.3

RUN apt update && \
    apt install  -y --no-install-recommends \
    # for igraph
    libxml2-dev \
    libglpk-dev \
    libgmp3-dev \
    # for httr
    libcurl4-openssl-dev \
    libssl-dev && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir templogging
ADD ["templogging.Rproj", ".Rprofile", "renv.lock", "/templogging/"]
# add all of the renv folder, except the library which is marked out in .dockerignore
ADD renv/ /templogging/renv

WORKDIR /templogging

RUN Rscript -e "renv::restore(repos='https://packagemanager.rstudio.com/all/__linux__/focal/latest', confirm=FALSE)"

ADD . /templogging

# CMD ["Rscript", "./run_targets.r"]
