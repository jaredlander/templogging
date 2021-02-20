FROM rocker/r-ver:4.0.3

# system libraries
RUN apt update && \
    apt install  -y --no-install-recommends \
    # for igraph
    libxml2-dev \
    libglpk-dev \
    libgmp3-dev \
    # for httr
    libcurl4-openssl-dev \
    libssl-dev && \
    # makes the image smaller
    rm -rf /var/lib/apt/lists/*

# create project directory
RUN mkdir templogging
# add some specific files
ADD ["templogging.Rproj", ".Rprofile", "renv.lock", "/templogging/"]
# add all of the renv folder, except the library which is marked out in .dockerignore
ADD renv/ /templogging/renv

# make sure we are in the project directory so restoring the packages works cleanly
WORKDIR /templogging

# this restores the desired packages (including specific versions)
# it uses the public RStudio package manager to get binary versions of the packages
# this is for faster installation
RUN Rscript -e "renv::restore(repos='https://packagemanager.rstudio.com/all/__linux__/focal/latest', confirm=FALSE)"

# then we add in the rest of the project folder, included all the code
# we do this separately so that we can change code without having to reinstall all the packages
ADD . /templogging

# CMD ["Rscript", "./run_targets.r"]
