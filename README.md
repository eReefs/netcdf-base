# netcdf-base

Docker base image definition for an environment that includes specific versions of the CURL, DAP, HDF5 and NetCDF C-libraries, as well as the related NCO, PROJ and GDAL tool suites that depend on those pre-requisites.

- [Installed Software Versions](#installed-software-versions)
- [Usage Example](#usage-example)

&nbsp;

# Useful Locations

The canonical location for the Dockerfile described here is <https://github.com/eReefs/netcdf-base>

Pre-compiled Docker images have been configured by the [CSIRO Coastal Informatics Team](https://research.csiro.au/coastal-informatics/), and can be obtained from [onaci/ereefs-netcdf-base](https://hub.docker.com/r/onaci/ereefs-netcdf-base), with a selection of base-images, including:

- `debian:12-slim`
- `python:3.11-slim-bookworm`
- `rocker/r-ver:4`

If you have need for a pre-built image that uses a different base image, please [raise a ticket](https://github.com/eReefs/netcdf-base/issues), and we will see what we can do.


&nbsp;

## Installed Software Versions

The [Dockerfile](./Dockerfile) specifies a number of build-time arguments that allow you to
control the versions of all the libraries and utilities that you want to build and install from source.

The values of these arguments will be available to derived images in environment variables that have the same name as the argument,  and also via Docker Labels.

| Build Argument / Environment Variable | What it Controls | Default Value | Docker Label |
|---------------------------------------|------------------|---------------|--------------|
| `BASE_IMAGE` | The docker base image that you want to install the netCDF and related libraries into.  This can be any relatively up-to-date apt-based image, e.g Debian 12 or Ubuntu 22.04. |`debian:12-slim` | `org.opencontainers.image.base.name` |
| `CURL_VERSION` | The version of `curl` (and `libcurl4-openssl-dev`) that you want to install, as the version in the OS package is often not up to date with the latest available. Most of the other software in this list depends on this selection. <https://curl.se/> |  `8.2.1` [released 2023-07-26](https://github.com/curl/curl/releases) | `se.curl.version` |
| `DAP_VERSION` | The version of the DAP++ SDK (`libdap-bin` and `libdap-dev`) that you want to install.  <https://www.opendap.org/software/libdap> | `3.20.11` [released 2022-07-21](https://www.opendap.org/pub/source/) | `org.opendap.dap.version` |
| `HDF5_VERSION` | The version of the HDF 5 library (`libhdf5-dev`) that should be compiled for testing. This will be compiled with support for parallel I/O with MPI (`--enable-parallel`), for thread-safe operation (`--enable-threadsafe`) and for AWS S3 file storage (`--enable-ros3-vfd`).  <https://portal.hdfgroup.org/display/HDF5/HDF5> | `1.14.0` [released 2023-02-08](https://support.hdfgroup.org/ftp/HDF5/releases/) | `org.hdfgroup.hdf5.version` |
| `AWS_SDK_CPP_REFSPEC` | The git branch or tag of the S3 library from the AWS C++ SDK that you want the NetCDF library to depend on. (Note: This SDK does not have formal release versions, only tags).  <https://github.com/aws/aws-sdk-cpp> | `main` (the latest available at the time of building) | `com.amazonaws.sdk.version` |
| `NETCDF_VERSION` | The version of the netCDF-C library that should be installed. The library will be linked against the results of your `DAP_VERSION`, `HDF5_VERSION` and `AWS_SDK_CPP_REFSPEC` selections, and with support for parallel I/O, NcZarr files and byte-range queries to files on AWS S3 storage.  <https://docs.unidata.ucar.edu/netcdf-c/current/index.html> | `4.9.2` [released 2023-03-14](https://github.com/Unidata/netcdf-c/releases) | `edu.ucar.unidata.netcdf.version` |
| `NCO_VERSION` | The version of the NetCDF Operators (NCO) that should be installed. These will be compiled against your choice of NetCDF library. <https://sourceforge.net/projects/nco/> | `5.1.7`, [released 2023-07-27](https://github.com/nco/nco/releases) | `net.sf.nco.version` |
| `PROJ_VERSION` | The version of the PROJ library (`proj-bin, libproj-dev`) to install.  This depends on your CURL_VERSION, and is a prerequisite for GDAL. <https://proj.org/en/stable/index.html> | `9.2.1` [released 3023-06-01](https://proj.org/en/stable/download.html) | `org.proj.version` |
| `GDAL_VERSION` | The version of GDAL that should be installed.   This will be compiled with support for (at minimum) geotiff, gif, hdf5, jpeg, json, netcdf, spatialite, sqlite, tiff and zarr, and will be linked against your chosen PROJ, HDF5 and NetCDF library versions.  It may also build with python or java bindings if those were pre-installed in your base image. <https://gdal.org/> | `3.7.2` [released 2023-09-13](https://gdal.org/download.html) | `org.gdal.version` |


&nbsp;

## Usage Example

To build a netcf-base container using any combination of base image and library versions:

```bash
BASE_IMAGE="python:3.11-slim-bookworm"

docker build --pull \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "CURL_VERSION=8.6.0" \
  --build-arg "DAP_VERSION=3.21.0-27" \
  --build-arg "GDAL_VERSION=3.8.3" \
  --build-arg "HDF5_VERSION=1.14.0" \
  --build-arg "NETCDF_VERSION=4.9.2" \
  --build-arg "NCO_VERSION=5.1.9" \
  --build-arg "PROJ_VERSION=9.3.1" \
  --tag "onaci/ereefs-netcdf-base:$(echo $BASE_IMAGE | tr ':' '-' | tr '/' '-')"
```

Installing all these packages from source is NOT a speedy operation, so be prepared for this build to take up to several hours.

&nbsp;
