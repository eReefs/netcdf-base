#------------------------------------------------------------------------------
# CSIRO eReefs NetCDF-Base
#------------------------------------------------------------------------------
# Allow the base-image to be selected at build time.
# This must be derived from an apt-compatible OS Image (e.g. debian, ubuntu etc)

ARG BASE_IMAGE="debian:12-slim"
FROM ${BASE_IMAGE} as default

# Record the actual base image used from the FROM command as a label.
ARG BASE_IMAGE
LABEL org.opencontainers.image.base.name=${BASE_IMAGE}

# Enable Bash in RUN commands, and ensure that any commands with
# pipes exit on the first failure.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Upgrade any packages and libraries already pre-installed by the base image
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update \
    && apt-get -y upgrade

# Install the OS packages that are prerequisites for our source-images
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update \
    && apt-get install --no-install-recommends -y \
        antlr \
        autoconf \
        automake \
        bsdextrautils \
        build-essential \
        bison \
        ca-certificates \
        cmake \
        csh \
        file \
        flex \
        gettext \
        git \
        gnupg2 \
        groff \
        gsl-bin \
        less \
        libantlr-dev \
        libexpat1-dev \
        libfl-dev \
        libfreexl-dev \
        libgif-dev \
        libgsl-dev \
        libjpeg62-turbo-dev \
        libjson-c-dev \
        libblosc-dev \
        liblz4-dev \
        libopenmpi-dev \
        libpng-dev \
        libpsl-dev \
        libpulse-dev \
        libsasl2-dev \
        libsqlite3-dev \
        libssl-dev \
        libtiff-dev \
        libtirpc3 \
        libtirpc-dev \
        libudunits2-0 \
        libudunits2-dev \
        libtool \
        libxml2-dev \
        libzip-dev \
        lsb-release \
        netcat-traditional \
        procps \
        sed \
        sqlite3 \
        udunits-bin \
        unzip \
        uuid-dev \
        wget \
        zlib1g-dev \
    && apt-get autoremove --purge

# Ensure the libraries we want to build and install from source are purged
# (in case the base image had them installed or one of our prerequisites had
# them as a dependency
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get purge -y \
        curl \
    && apt-get purge -y \
        libcurl4-openssl-dev \
    && apt-get purge -y \
        libdap-dev \
    && apt-get purge -y \
        libhdf5-dev \
    && apt-get purge -y \
        libnetcdf-dev \
    && apt-get purge -y \
        nco \
    && apt-get autoremove --purge

# Identify the path for the MPI library headers, defaulting to the location for an 
# x86_64 CPU architecture if the builder has not specified anything different.
ARG MPI_INCLUDE_PATH
ENV MPI_INCLUDE_PATH="${MPI_INCLUDE_PATH:-/usr/lib/x86_64-linux-gnu/openmpi/include}"

#------------------------------------------------------------------------------
# Install a specific version of libcurl and curl from source
# Instructions: https://curl.se/docs/install.html
# Versions: https://github.com/curl/curl/releases
# prerequisites: libssl-dev, libpsl-dev
#------------------------------------------------------------------------------
ARG CURL_VERSION
ENV CURL_VERSION="${CURL_VERSION:-8.6.0}"
ENV CURL_SRC_DIR="/usr/local/src/curl-${CURL_VERSION}"
RUN --mount=target="${CURL_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${CURL_SRC_DIR}/configure" ]; then \
        wget -O - "https://github.com/curl/curl/releases/download/curl-$(echo "${CURL_VERSION}" | tr '.' '_')/curl-${CURL_VERSION}.tar.gz"  | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${CURL_SRC_DIR}",type=cache,sharing=locked \
    cd "${CURL_SRC_DIR}" \
    && ./configure --prefix=/usr/local --with-openssl --enable-versioned-symbols \
    && make \
    && make install \
    && ldconfig
LABEL se.curl.version=${CURL_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of libdap from source
# Instructions: https://github.com/OPENDAP/libdap4/blob/master/INSTALL
# Versions: https://github.com/OPENDAP/libdap4/releases
# Prerequisites:
# - automake autoconf libtool bison, flex & libfl-dev, col (from bsdextrautils)
# - libcurl, libtirpc, libxml2, libuuid
# See https://www.opendap.org/allsoftware/third-party
#
# Note: the CPPFLAGS and LIBS variables are needed to make the compiler look
#       for the XDR functions in libtirpc instead of glibc, since they are
#       no longer in glibc from Debian 12 onwards.
#------------------------------------------------------------------------------
ARG DAP_VERSION
ENV DAP_VERSION="${DAP_VERSION:-3.21.0-27}"
ENV DAP_SRC_DIR="/usr/local/src/libdap4-${DAP_VERSION}"
RUN --mount=target="${DAP_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${DAP_SRC_DIR}/configure" ]; then \
        wget -O - "https://github.com/OPENDAP/libdap4/archive/refs/tags/${DAP_VERSION}.tar.gz"  | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${DAP_SRC_DIR}",type=cache,sharing=locked \
    cd "${DAP_SRC_DIR}" \
    && autoreconf --force --install --verbose \
    && CPPFLAGS="-I/usr/include/tirpc" LIBS="-ltirpc" ./configure --prefix=/usr/local \
    && make \
    && make install \
    && ldconfig
LABEL org.opendap.dap.version=${DAP_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of libhdf5 from source
# Warning: This is *slow*!
# Instructions: https://github.com/HDFGroup/hdf5/blob/develop/release_docs/INSTALL
# Versions: https://support.hdfgroup.org/ftp/HDF5/releases/
# Prerequisites: zlib, MPI, MPI-IO
#
# Note: The --enable-parallel setting will be inherited by the NetCDF-C library
#       when it discovers and links against this HDF5 library.
# Note: The --enable-ros-vfd flag enables a read-only virtual file driver
#       for HDF5 files on AWS S3 storage.  The NetCDF-C library that links
#       against this HDF5 library uses it to perform byte-range access to
#       NetCDF files on AWS S3 Storage.
#       S3-support in the NetCDF-C library.
#------------------------------------------------------------------------------
ARG HDF5_VERSION
ENV HDF5_VERSION="${HDF5_VERSION:-1.14.0}"
ENV HDF5_SRC_DIR="/usr/local/src/hdf5-${HDF5_VERSION}"
RUN --mount=target="${HDF5_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${HDF5_SRC_DIR}/configure" ]; then \
        wget -O - https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-$(echo "${HDF5_VERSION}" | sed -r 's/([[:digit:]]+\.[[:digit:]]+).*/\1/')/hdf5-${HDF5_VERSION}/src/hdf5-${HDF5_VERSION}.tar.bz2 | tar -xj -C /usr/local/src/; \
    fi
RUN --mount=target="${HDF5_SRC_DIR}",type=cache,sharing=locked \
    cd "${HDF5_SRC_DIR}" \
    && ./configure --prefix=/usr/local --enable-parallel --enable-threadsafe --enable-unsupported --enable-ros3-vfd \
    && make install \
    && ldconfig
LABEL org.hdfgroup.hdf5.version=${HDF5_VERSION}

#------------------------------------------------------------------------------
# Build the AWS S3 C++ SDK from source
# Instructions: https://docs.aws.amazon.com/sdk-for-cpp/v1/developer-guide/setup-linux.html
# Instructions: https://github.com/Unidata/netcdf-c/blob/main/docs/cloud.md
# Prerequisites: libcurl, libopenssl, libuuid, zlib, libpulse
#
# Note: This SDK is a prerequisite for the NetCDF-C library to enable NCZarr
#       access to Zarr-formatted datasets on S3.
#------------------------------------------------------------------------------
ARG AWS_SDK_CPP_REFSPEC
ENV AWS_SDK_CPP_REFSPEC="${AWS_SDK_CPP_REFSPEC:-main}"
ENV AWS_SDK_CPP_SRC_DIR="/usr/local/src/aws-sdk-cpp"
RUN --mount=target="${AWS_SDK_CPP_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${AWS_SDK_CPP_SRC_DIR}/.gitmodules" ]; then \
        mkdir -p /usr/local/src/aws-sdk-cpp \
        && cd /usr/local/src/aws-sdk-cpp \
        && git clone https://github.com/aws/aws-sdk-cpp . \
        && git checkout "${AWS_SDK_CPP_REFSPEC}" \
        && git submodule update --init --recursive; \
    fi
RUN --mount=target="${AWS_SDK_CPP_SRC_DIR}",type=cache,sharing=locked \
    mkdir -p "${AWS_SDK_CPP_SRC_DIR}/build" \
    && cd "${AWS_SDK_CPP_SRC_DIR}/build" \
    && cmake ../ \
        -DBUILD_ONLY="s3" \
        -DENABLE_UNITY_BUILD=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_MODULE_PATH=/usr/local/cmake \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_PREFIX_PATH=/usr/local \
        -DCMAKE_POLICY_DEFAULT_CMP0075=NEW \
        -DSIMPLE_INSTALL=ON \
    && cmake --build . --config Release \
    && cmake --install . --config Release
LABEL com.amazonaws.sdk.version=${AWS_SDK_CPP_REFSPEC}

#------------------------------------------------------------------------------
# Install a specific version of netCDF-C from source
# Instructions: https://github.com/Unidata/netcdf-c/blob/main/INSTALL.md
# Versions: https://github.com/Unidata/netcdf-c/releases
# Prerequisites: curl, libdap, libhdf5, zlib, aws-sdk-cpp/s3
#
# NOTE1: This build should auto-detect the libhdf5 library compiled above,
#        and will detect and and inherit the parallel and zarr support from it.
# NOTE2: CPATH is needed as mpi header files from the package manager are
#        not in a standard location, and the NetCDF build can't discover
#        that location the way it discovers it *needs* the openmpi headers.
# NOTE3: LDFLAGS is used to make this build link with the AWS-SDK-CPP S3
#        library compiled above in response to use of the --enable-s3 flag.
#------------------------------------------------------------------------------
ARG NETCDF_VERSION
ENV NETCDF_VERSION="${NETCDF_VERSION:-4.9.2}"
ENV NETCDF_SRC_DIR="/usr/local/src/netcdf-c-${NETCDF_VERSION}"
RUN --mount=target="${NETCDF_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${NETCDF_SRC_DIR}/configure" ]; then \
        wget -O - https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_VERSION}.tar.gz | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${NETCDF_SRC_DIR}",type=cache,sharing=locked \
    cd "${NETCDF_SRC_DIR}" \
    && CPATH="${MPI_INCLUDE_PATH}" CC=mpicc LDFLAGS="-L/usr/local/lib -laws-cpp-sdk-s3" ./configure \
      --prefix=/usr/local \
      --enable-hdf5 \
      --enable-dap \
      --enable-nczarr \
      --enable-plugins \
      --enable-remote-functionality \
      --enable-s3 \
      --enable-utilities \
      --disable-external-server-tests \
      --disable-dap-remote-tests \
      --disable-large-file-tests \
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
ENV NCO_VERSION="${NCO_VERSION:-5.1.9}"
ENV NCO_SRC_DIR="/usr/local/src/nco-${NCO_VERSION}"
RUN --mount=target="${NCO_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${NCO_SRC_DIR}/configure" ]; then \
        wget -O - https://github.com/nco/nco/archive/${NCO_VERSION}.tar.gz | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${NCO_SRC_DIR}",type=cache,sharing=locked \
    cd "${NCO_SRC_DIR}" \
    && ./configure --prefix=/usr/local \
    && make install \
    && ldconfig
LABEL net.sf.nco.version=${NCO_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of proj from source, ensuring it links with our
# selected version of libcurl and curl. 
# libproj is a prerequisite for libgeotiff-dev and GDAL.
#
# Instructions: https://proj.org/en/stable/install.html#compilation-and-installation-from-source-code
# Versions: https://proj.org/en/stable/download.html#current-release
# Prerequisites: cmake, libsqlite3-dev, libtiff-dev
#------------------------------------------------------------------------------
ARG PROJ_VERSION
ENV PROJ_VERSION="${PROJ_VERSION:-9.3.1}"
ENV PROJ_SRC_DIR="/usr/local/src/proj-${PROJ_VERSION}"
RUN --mount=target="${PROJ_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${PROJ_SRC_DIR}/cmake" ]; then \
        wget -O - https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${PROJ_SRC_DIR}",type=cache,sharing=locked \
    mkdir -p "${PROJ_SRC_DIR}/build" \
    && cd "${PROJ_SRC_DIR}/build" \
    && cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build . \
    && cmake --build . --target install
LABEL org.proj.version=${PROJ_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of geos from source, since GEOS is a prerequisite
# for GDAL, which is picky about version compatibility. (Also, the default
# version on most operating system base images is fairly out of date)
#
# Instructions and versions: https://libgeos.org/usage/download/
#------------------------------------------------------------------------------
ARG GEOS_VERSION
ENV GEOS_VERSION="${GEOS_VERSION:-3.12.1}"
ENV GEOS_SRC_DIR="/usr/local/src/geos-${GEOS_VERSION}"
RUN --mount=target="${GEOS_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${GEOS_SRC_DIR}/cmake" ]; then \
        wget -O - "https://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2" | bunzip2 | tar x -C /usr/local/src; \
    fi
RUN --mount=target="${GEOS_SRC_DIR}",type=cache,sharing=locked \
    mkdir -p "${GEOS_SRC_DIR}/build" \
    && cd "${GEOS_SRC_DIR}/build" \
    && cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
    && make \
    && make install
LABEL org.geos.version=${GEOS_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of libgeotiff from source, ensuring it links 
# with our selected version of proj.  libgeotiff is a prerequisite for GDAL.
#
# Instructions: https://trac.osgeo.org/geotiff/ticket/17
# Versions: https://github.com/OSGeo/libgeotiff/releases
# Prerequisites: proj, libsqlite3-dev, libtiff-dev
#------------------------------------------------------------------------------
ARG GEOTIFF_VERSION
ENV GEOTIFF_VERSION="${GEOTIFF_VERSION:-1.7.1}"
ENV GEOTIFF_SRC_DIR="/usr/local/src/libgeotiff-${GEOTIFF_VERSION}"
RUN --mount=target="${GEOTIFF_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${GEOTIFF_SRC_DIR}/cmake" ]; then \
        wget -O - "https://github.com/OSGeo/libgeotiff/releases/download/${GEOTIFF_VERSION}/libgeotiff-${GEOTIFF_VERSION}.tar.gz" | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${GEOTIFF_SRC_DIR}",type=cache,sharing=locked \
    mkdir -p "${GEOTIFF_SRC_DIR}/build" \
    && cd "${GEOTIFF_SRC_DIR}/build" \
    && cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DWITH_JPEG=ON \
        -DWITH_ZLIB=ON \
    && cmake --build . \
    && cmake --build . --target install
LABEL org.libgeotiff.version=${GEOTIFF_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of GDAL from source, ensuring it links with our
# selected versions of libhdf5, libnetcdf, libproj and libgeos
#
# Instructions: https://gdal.org/development/building_from_source.html
# Versions: https://gdal.org/download.html
# Prerequisites: libcurl, libgeos, libhdf5, libnetcdf, libproj, libsqlite3 and libsqlite3-dev
#
# NOTE1: Blosc is an additional prerequisite for the zarr driver
# NOTE2: If we want to add spatialite support, we need to build librttopo
#        and libspatialite from source due to proj and geos dependencies.
#        As none of our downstream apps need it yet, skip that for now.
#------------------------------------------------------------------------------
ARG GDAL_VERSION
ENV GDAL_VERSION="${GDAL_VERSION:-3.8.3}"
ENV GDAL_SRC_DIR="/usr/local/src/gdal-${GDAL_VERSION}"
RUN --mount=target="${GDAL_SRC_DIR}",type=cache,sharing=locked \
    if [ ! -f "${GDAL_SRC_DIR}/cmake" ]; then \
        wget -O - https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz | tar -xz -C /usr/local/src/; \
    fi
RUN --mount=target="${GDAL_SRC_DIR}",type=cache,sharing=locked \
    mkdir -p "${GDAL_SRC_DIR}/build" \
    && cd "${GDAL_SRC_DIR}/build" \
    && CC=mpicc CXX=mpic++ cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DMPI_INCLUDE_PATH="${MPI_INCLUDE_PATH}" \
        -DGDAL_SET_INSTALL_RELATIVE_RPATH=ON \
        -DGDAL_USE_BLOSC=ON \
        -DGDAL_USE_CURL=ON \
        -DGDAL_USE_GEOTIFF=ON \
        -DGDAL_USE_GEOS=ON \
        -DGDAL_USE_GIF=ON \
        -DGDAL_USE_HDF5=ON \
        -DGDAL_ENABLE_HDF5_GLOBAL_LOCK=OFF \
        -DGDAL_USE_JPEG=ON \
        -DGDAL_USE_JSONC=ON \
        -DGDAL_USE_LIBXML2=ON \
        -DGDAL_USE_LZ4=ON \
        -DGDAL_USE_NETCDF=ON \
        -DGDAL_USE_OPENSSL=ON \
        -DGDAL_USE_PNG=ON \
        -DGDAL_USE_SPATIALITE=OFF \
        -DGDAL_USE_SQLITE3=ON \
        -DGDAL_USE_TIFF=ON \
        -DGDAL_USE_ZLIB=ON \
    && cmake --build . \
    && cmake --build . --target install
LABEL org.gdal.version=${GDAL_VERSION}

#------------------------------------------------------------------------------
# CSIRO eReefs NetCDF Python Base
# This extension handles installing some common python libraries which
# depend on the NetCDF-related C libraries installed by the default target
#------------------------------------------------------------------------------
FROM default as python

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHON_HELPER_DIR='/usr/local/src/python-netcdf-helper'

RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --upgrade pip wheel setuptools

COPY ./python "${PYTHON_HELPER_DIR}/"
RUN --mount=type=cache,target=/root/.cache/pip \
    chmod 0755 "${PYTHON_HELPER_DIR}/pip3-netcdf-install.sh" && \
    ln -s "${PYTHON_HELPER_DIR}/pip3-netcdf-install.sh" /usr/local/bin/pip3-netcdf-install && \
    pip3-netcdf-install
