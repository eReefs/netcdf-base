#!/bin/bash

# This script can be called in lieu of `pip3 install -r requirements.txt`
# It takes the path to a python requirements file as an argument
# (Defaulting to the one installed side-by-side with the script)
# and ensures that the Python NetCDF libraries are installed *first* in
# a way that links them properly against the NetCDF-C library that has
# already been installed.
REQUIREMENTS_TXT="${1:-}"
if [[ -z "${REQUIREMENTS_TXT}" ]] || [[ ! -f "${REQUIREMENTS_TXT}" ]]; then
    THIS_SCRIPT=$(realpath "${BASH_SOURCE[0]}")
    THIS_DIR=$( cd "$(dirname "${THIS_SCRIPT}")" && pwd)
    REQUIREMENTS_TXT="${THIS_DIR}/requirements.txt"
fi

pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-binary mpi4py \
	numpy shapely vincenty mpi4py Cython

CPATH="${MPI_INCLUDE_PATH}" pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-build-isolation \
	--no-binary netcdf4 \
	netcdf4

pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-build-isolation \
	--no-binary nco \
	--no-binary pydap \
	--no-binary pyproj \
	nco pydap pyproj

CPATH="${MPI_INCLUDE_PATH}" pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-build-isolation \
	--no-binary gdal \
	gdal

pip3 install -r "${REQUIREMENTS_TXT}"
