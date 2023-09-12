# netcdf-base

Docker base image definition for an environment that includes specific versions of the CURL, DAP, HDF5 and NetCDF C-libraries, as well as the related NCO tool suite.

- [Build Arguments](#build-arguments)
- [Usage Example](#usage-example)
- [Pre-built docker images](#pre-built-docker-images)


&nbsp;

## Build Arguments

The [Dockerfile](./Dockerfile) specifies a number of build-time arguments that allow you to
control the versions of all the libraries that you want to build and install from source:

- `BASE_IMAGE` => The docker base image that you want to install the netCDF and related libraries into.  This can be any apt-based image, and defaults to `debian:11-slim`.
- `CURL_VERSION` => The version of `curl` (and `libcurl`) that you want to install. Default is `8.2.1`, [released 2023-07-26](https://github.com/curl/curl/releases)
- `DAP_VERSION` => The version of `libdap` that you want to install that should be used for testing. Default is `3.18.1`, [released 2016-07-06](https://www.opendap.org/software/libdap)
- `HDF5_VERSION` => The version of the HDF 5 library that should be compiled for testing. Default is `1.14.0`, [released 2023-02-08](https://support.hdfgroup.org/ftp/HDF5/releases/). (Note for HDF5 v1.14+, you need netcdf 4.9.2 or later)
- `NETCDF_VERSION` => The version of the netCDF-C library that should be compiled for testing. Default is `4.9.2`, [released 2023-03-14](https://github.com/Unidata/netcdf-c/releases)
- `NCO_VERSION` => The version of the NCO tools that should be installed. Default is `5.1.7`, [released 2023-07-27](https://github.com/nco/nco/releases)


All the values of these build arguments will be available to the compiled container as environment variables of the same name, and also as docker labels.


&nbsp;

## Usage Example

To build a netcf-base container using any combination of base image and library versions:

```bash
# Define variables for your build arguments
BASE_IMAGE="python:3.11-slim-bullseye"
CURL_VERSION="8.2.1"
DAP_VERSION="3.18.1"
HDF5_VERSION="1.14.0"
NETCDF_VERSION="4.9.2"
NCO_VERSION="5.1.7"

# Build your custom netcdf-base image
docker build --pull \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "CURL_VERSION=${CURL_VERSION}" \
  --build-arg "DAP_VERSION=${DAP_VERSION}" \
  --build-arg "HDF5_VERSION=${HDF5_VERSION}" \
  --build-arg "NETCDF_VERSION=${NETCDF_VERSION}" \
  --build-arg "NCO_VERSION=${NCO_VERSION}" \
  --tag "netcdf-base-${BASE_IMAGE}-curl${CURL_VERSION}-dap${DAP_VERSION}-hdf5${HDF5_VERSION}-netcdf${NETCDF_VERSION}-nco${NCO_VERSION}"
```
The build may take quite a while, as installing all these packages from source is not a speedy operation!

&nbsp;

## Pre-built docker images

The [CSIRO Coastal Informatics Team](https://research.csiro.au/coastal-informatics/) have an automated docker build that publishes images derived from this repository to DockerHub at [onaci/ereefs-netcdf-base](https://hub.docker.com/r/onaci/ereefs-netcdf-base).

The variants that are built each time a commit is pushed to the `main` branch of this repository are:

- `onaci/ereefs-netcdf-base:latest`  uses all default build arguments, so is based on `debian:11-slim`
- `onaci/ereefs-netcdf-base:python-3.11-slim-bullseye`  is built with `--build-arg BASE_IMAGE=python:3.11-slim-bullseye`
- `onaci/ereefs-netcdf-base:r-base-4.3.1` is built with `--build-arg BASE_IMAGE=r-base:4.3.1`

If you have need for a pre-built image that uses a different base image, please [raise a ticket](https://github.com/eReefs/netcdf-base/issues), and we will see what we can do.
