#------------------------------------------------------------------------------
# CSIRO eReefs NetCDF-Base
#------------------------------------------------------------------------------
# Allow the base-image to be selected at build time.
# This must be derived from an apt-compatible OS Image (e.g. debian, ubuntu etc)

ARG BASE_IMAGE="debian:12-slim"
FROM ${BASE_IMAGE}

# Record the actual base image used from the FROM command as a label.
ARG BASE_IMAGE
LABEL org.opencontainers.image.base.name=${BASE_IMAGE}

# Enable Bash in RUN commands, and ensure that any commands with
# pipes exit on the first failure.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Upgrade any packages and libraries already pre-installed by the base image
RUN apt-get update \
    && apt-get -y upgrade

# Install the OS packages that are prerequisites for our source-images
RUN apt-get update \
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
        libgeotiff-dev \
        libgif-dev \
        libgsl-dev \
        libjpeg62-turbo-dev \
        libjson-c-dev \
        libblosc-dev \
        liblz4-dev \
        libopenmpi-dev \
        libpng-dev \
        libpulse-dev \
        libsasl2-dev \
        libsqlite3-dev \
        libspatialite-dev \
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
RUN apt-get purge -y \
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

# Clean up the package cache
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#------------------------------------------------------------------------------
# Install a specific version of libcurl and curl from source
# Instructions: https://curl.se/docs/install.html
# Versions: https://github.com/curl/curl/releases
# prerequisites: libssl-dev
#------------------------------------------------------------------------------
ARG CURL_VERSION
ENV CURL_VERSION="${CURL_VERSION:-8.2.1}"
RUN wget -O - "https://github.com/curl/curl/releases/download/curl-$(echo "${CURL_VERSION}" | tr '.' '_')/curl-${CURL_VERSION}.tar.gz"  | tar -xz -C /usr/local/src/
RUN cd /usr/local/src/curl-${CURL_VERSION}/ \
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
ENV DAP_VERSION="${DAP_VERSION:-3.20.11}"
RUN wget -O - "https://github.com/OPENDAP/libdap4/archive/refs/tags/${DAP_VERSION}.tar.gz"  | tar -xz -C /usr/local/src/
RUN cd /usr/local/src/libdap4-${DAP_VERSION} \
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
RUN wget -O - https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-$(echo "${HDF5_VERSION}" | sed -r 's/([[:digit:]]+\.[[:digit:]]+).*/\1/')/hdf5-${HDF5_VERSION}/src/hdf5-${HDF5_VERSION}.tar.bz2 | tar -xj -C /usr/local/src/
RUN cd /usr/local/src/hdf5-${HDF5_VERSION} \
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
RUN mkdir /usr/local/src/aws-sdk-cpp \
    && cd /usr/local/src/aws-sdk-cpp \
    && git clone https://github.com/aws/aws-sdk-cpp . \
    && git checkout "${AWS_SDK_CPP_REFSPEC}" \
    && git submodule update --init --recursive
RUN mkdir /usr/local/src/aws-sdk-cpp/build \
    && cd /usr/local/src/aws-sdk-cpp/build \
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
RUN wget -O - https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_VERSION}.tar.gz | tar -xz -C /usr/local/src/
RUN cd /usr/local/src/netcdf-c-${NETCDF_VERSION}/ \
    && CPATH=/usr/lib/x86_64-linux-gnu/openmpi/include CC=mpicc LDFLAGS="-L/usr/local/lib -laws-cpp-sdk-s3" ./configure \
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
    && make check install \
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
RUN wget -O - https://github.com/nco/nco/archive/${NCO_VERSION}.tar.gz | tar -xz -C /usr/local/src/
RUN find /usr -name '*netcdf*'
RUN cd /usr/local/src/nco-${NCO_VERSION}/ \
    && ./configure --prefix=/usr/local \
    && make install \
    && ldconfig
LABEL net.sf.nco.version=${NCO_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of proj from source, ensuring it links with our
# selected version of libcurl and curl.  proj is a prerequisite for GDAL.
#
# Instructions: https://proj.org/en/stable/install.html#compilation-and-installation-from-source-code
# Versions: https://proj.org/en/stable/download.html#current-release
# Prerequisites: cmake, libsqlite3-dev, libtiff-dev
#------------------------------------------------------------------------------
ARG PROJ_VERSION
ENV PROJ_VERSION="${PROJ_VERSION:-9.2.1}"
RUN wget -O - https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz | tar -xz -C /usr/local/src/
RUN mkdir -p /usr/local/src/proj-${PROJ_VERSION}/build \
    && cd /usr/local/src/proj-${PROJ_VERSION}/build \
    && cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build . \
    && cmake --build . --target install
LABEL org.proj.version=${PROJ_VERSION}

#------------------------------------------------------------------------------
# Install a specific version of GDAL from source, ensuring it links with our
# selected versions of libhdf5, libnetcdf and libproj
#
# Instructions: https://gdal.org/development/building_from_source.html
# Versions: https://gdal.org/download.html
# Prerequisites: libcurl, libhdf5, libnetcdf, libproj, libsqlite3 and libsqlite3-dev
#
# NOTE1: Blosc is an additional prerequisite for the zarr driver

#------------------------------------------------------------------------------
ARG GDAL_VERSION
ENV GDAL_VERSION="${GDAL_VERSION:-3.7.2}"
RUN wget -O - https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz | tar -xz -C /usr/local/src/
RUN mkdir -p /usr/local/src/gdal-${GDAL_VERSION}/build \
    && cd /usr/local/src/gdal-${GDAL_VERSION}/build \
    && CC=mpicc CXX=mpic++ cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DMPI_INCLUDE_PATH=/usr/lib/x86_64-linux-gnu/openmpi/include \
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
        -DGDAL_USE_SPATIALITE=ON \
        -DGDAL_USE_SQLITE3=ON \
        -DGDAL_USE_TIFF=ON \
        -DGDAL_USE_ZLIB=ON \
    && cmake --build . \
    && cmake --build . --target install
LABEL org.gdal.version=${GDAL_VERSION}
