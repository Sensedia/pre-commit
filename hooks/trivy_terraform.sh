#!/bin/env bash
#
# shellcheck disable=SC2086 # allow to pass arguments as a string

set -eo pipefail

# color
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
ENDCOLOR='\033[0m'

# Validate Dependencies
if ! command -v trivy &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Neither 'trivy' binary or 'docker' found!${ENDCOLOR}"
    exit 1
fi

# Parsing arguments
function parse_args() {
    local -r args=("$@")
    for arg in "${args[@]}"; do

        if [[ -f $arg ]] || [[ -d $arg ]]; then
            DIR="$DIR $(dirname "$arg")"
        else
            ARGS="$ARGS $arg"
        fi
    done
}

# Scanning directories
function trivy_scan() {
    local trivy_bin

    # Trying running trivy binary first
    # and downloading latest definitions
    if command -v trivy &> /dev/null; then
        trivy image --download-db-only
        trivy_bin=1

    else
        echo -e "${RED}Trivy binary not found!${ENDCOLOR}"
        echo -e "${BLUE}Trying to run trivy docker image...${ENDCOLOR}"
        trivy_bin=0

    fi

    for dir in $DIR; do
        echo -e "\n---------------------------------------"
        echo "SCANNING -> $dir"
        echo -e "---------------------------------------\n"

        if [[ $trivy_bin -eq 1 ]]; then
            trivy config ${ARGS} "$dir"

        else
            docker run --rm -v "$PWD:/src:rw,Z" -w "/src" aquasec/trivy:latest config \
                --cache-dir /src/.pre-commit-trivy-cache \
                ${ARGS} "$dir"

        fi

        echo -e "\n${GREEN}NO PROBLEMS FOUND!!!${ENDCOLOR}"
    done
}

parse_args "$@"

# Removing repeated elements
DIR=$(echo "$DIR" | tr ' ' '\n' | sort -u | tr '\n' ' ')

trivy_scan
