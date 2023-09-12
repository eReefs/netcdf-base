#------------------------------------------------------------------------------
# CSIRO eReefs NetCDF-Base
#------------------------------------------------------------------------------
# Allow the base-image to be selected at build time.
# This must be derived from an apt-compatible OS Image (e.g. debian, ubuntu etc)

ARG BASE_IMAGE="debian:11-slim"
FROM ${BASE_IMAGE}

# Record the actual base image used from the FROM command as a label.
ARG BASE_IMAGE
LABEL org.opencontainers.image.base.name=${BASE_IMAGE}

# Enable Bash in RUN commands
SHELL [ "/bin/bash", "-c"]

# 1. Upgrade any packages and libraries already pre-installed by the base image
# 2. Ensure the libraries we want to build and install from source are purged (in case the base image had them installed)
# 3. Install the OS packages that are prerequisites for our source-images
# 4. Clean up the package cache
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get purge -y \
        curl \
        libcurl4-openssl-dev \
        libdap-dev \
        libhdf5-dev \
        libnetcdf-dev \
        nco \
    && apt-get install --no-install-recommends -y \
        antlr \
        build-essential \
        bison \
        bsdmainutils \
        ca-certificates \
        csh \
        curl \
        file procps \
        flex \
        git \
        gnupg2 \
        graphviz \
        groff \
        gsl-bin \
        less \
        libantlr-dev \
        libexpat1-dev \
        libfl-dev \
        libgdal-dev \
        libgraphviz-dev \
        libgsl-dev \
        libopenmpi-dev \
        libsasl2-dev \
        libssl-dev \
        libudunits2-0 \
        libudunits2-dev \
        lsb-release \
        netcat \
        proj-bin \
        sed \
        subversion \
        udunits-bin \
        vim \
        wget \
        zlib1g-dev \
    && apt-get clean \
    && apt-get autoremove --purge \
    && rm -rf /var/lib/apt/lists/*

#------------------------------------------------------------------------------
# Install a specific version of libcurl and curl from source
# Instructions: https://curl.se/docs/install.html
# Versions: https://github.com/curl/curl/releases
# prerequisites: libssl
#------------------------------------------------------------------------------
ARG CURL_VERSION
ENV CURL_VERSION="${CURL_VERSION:-8.2.1}"
RUN wget -O - "https://github.com/curl/curl/releases/download/curl-$(echo "${CURL_VERSION}" | tr '.' '_')/curl-${CURL_VERSION}.tar.gz"  | tar -xz -C /usr/local/src/ \
    && cd /usr/local/src/curl-${CURL_VERSION}/ \
    && ./configure --prefix=/usr/local --with-openssl \
    && make \
    && make install \
    && ldconfig
LABEL se.curl.version=${CURL_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of libdap from source
# Instructions: https://github.com/OPENDAP/libdap/blob/master/INSTALL
# Versions: https://www.opendap.org/software/libdap
# Prerequisites: libxml2, libz, bison, flex & libfl-dev, groff, col See https://www.opendap.org/allsoftware/third-party
#------------------------------------------------------------------------------
ARG DAP_VERSION
ENV DAP_VERSION="${DAP_VERSION:-3.18.1}"
RUN wget -O - "https://www.opendap.org/pub/source/libdap-${DAP_VERSION}.tar.gz"  | tar -xz -C /usr/local/src/ \
    && cd /usr/local/src/libdap-${DAP_VERSION}/ \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && ldconfig
LABEL org.opendap.dap.version=${DAP_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of HDF5 from source
# Warning: This is *slow*!
# Instructions: https://github.com/HDFGroup/hdf5/blob/develop/release_docs/INSTALL
# Versions: https://support.hdfgroup.org/ftp/HDF5/releases/
# Prerequisites: zlib, MPI, MPI-IO
#------------------------------------------------------------------------------
ARG HDF5_VERSION
ENV HDF5_VERSION="${HDF5_VERSION:-1.14.0}"
RUN wget -O - https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-$(echo "${HDF5_VERSION}" | sed -r 's/([[:digit:]]+\.[[:digit:]]+).*/\1/')/hdf5-${HDF5_VERSION}/src/hdf5-${HDF5_VERSION}.tar.bz2 | tar -xj -C /usr/local/src/ \
    && cd /usr/local/src/hdf5-${HDF5_VERSION} \
    && ./configure --prefix=/usr/local --enable-parallel --enable-threadsafe --enable-unsupported \
    && make install \
    && ldconfig
LABEL org.hdfgroup.hsf5.version=${HDF5_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of netCDF-C from source
# Instructions: https://github.com/Unidata/netcdf-c/blob/main/INSTALL.md
# Versions: https://github.com/Unidata/netcdf-c/releases
# Prerequisites: curl zlib, hdf5
#
# NOTE1: CPATH is needed as mpi header files from the package manager are not in a standard location.
# NOTE2: There is no specific way to tell configure which HDF5 library to use,
#        we can only influence it by making sure it's on the inc/lib paths if we built from source
#        and having it in /usr/local/lib does the trick.
#------------------------------------------------------------------------------
ARG NETCDF_VERSION
ENV NETCDF_VERSION="${NETCDF_VERSION:-4.9.2}"
RUN wget -O - https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_VERSION}.tar.gz | tar -xz -C /usr/local/src/ \
    && cd /usr/local/src/netcdf-c-${NETCDF_VERSION}/ \
    && export CPATH=/usr/lib/x86_64-linux-gnu/openmpi/include \
    && ./configure --prefix=/usr/local \
    && make install \
    && ldconfig
LABEL edu.ucar.unidata.netcdf.version=${NETCDF_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of the NCO utilities from source
# (Must be installed from source if netcdf is, or else the package dependency on
# libnetcdf will override our netcdf version)
# Instructions: https://github.com/nco/nco/blob/master/INSTALL
# Versions: https://github.com/nco/nco/releases
# Prerequisites: ANTLR, GSL, netCDF, OPeNDAP, UDUnits
#------------------------------------------------------------------------------
ARG NCO_VERSION
ENV NCO_VERSION="${NCO_VERSION:-5.1.7}"
RUN wget -O - https://github.com/nco/nco/archive/${NCO_VERSION}.tar.gz | tar -xz -C /usr/local/src/ \
    && cd /usr/local/src/nco-${NCO_VERSION}/ \
    && ./configure --prefix=/usr/local \
    && make install \
    && ldconfig
LABEL net.sf.nco.version=${NCO_VERSION}
