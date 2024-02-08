#!/bin/bash

# This script can be called to ensure that python libraries corresponding with
# the C and C++ libraries we have installed from source are installed AND
# properly linked against our compilation results.
#
# It accepts a single argument, being a requirements.txt file that will
# be used to *constrain* the versions of the python libs, defaulting
# to the one co-located with itself.
REQUIREMENTS_TXT="${1:-}"
if [[ -z "${REQUIREMENTS_TXT}" ]] || [[ ! -f "${REQUIREMENTS_TXT}" ]]; then
    THIS_SCRIPT=$(realpath "${BASH_SOURCE[0]}")
    THIS_DIR=$( cd "$(dirname "${THIS_SCRIPT}")" && pwd)
    REQUIREMENTS_TXT="${THIS_DIR}/requirements.txt"
fi

pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-binary mpi4py \
	mpi4py Cython

CPATH="${MPI_INCLUDE_PATH}" pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-build-isolation \
	--no-binary netcdf4 \
	netcdf4

pip3 install \
	--constraint "${REQUIREMENTS_TXT}" \
	--no-build-isolation \
	--no-binary gdal \
	--no-binary nco \
	--no-binary pydap \
	--no-binary pyproj \
	gdal=="${GDAL_VERSION}" nco pydap pyproj
