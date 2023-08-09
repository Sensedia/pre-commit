#!/bin/env bash
#
# shellcheck disable=SC2086 # allow to pass arguments as a string

set -eo pipefail

# color
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
ENDCOLOR='\033[0m'

function parse_args() {
    local -r args=("$@")
    for arg in "${args[@]}"; do
        #check if arg is a dir
        if [[ -f $arg ]] || [[ -d $arg ]]; then
            DIR="$DIR $(dirname "$arg")"
        else
            ARGS="$ARGS $arg"
        fi
    done
}

function trivy_scan() {
    for dir in $DIR; do
        echo -e "\n---------------------------------------"
        echo "SCANNING -> $dir"
        echo -e "---------------------------------------\n"

        if [[ $trivy_bin -eq 1 ]]; then

            trivy config ${ARGS} "$dir"
        else
            # Running trivy docker image
            docker run --rm -v "$PWD:/src:rw,Z" -w "/src" aquasec/trivy:latest config \
                --cache-dir /src/.pre-commit-trivy-cache \
                ${ARGS} "$dir"
        fi

        echo -e "\n${GREEN}NO PROBLEMS FOUND!!!${ENDCOLOR}"
    done
}

# Parsing arguments
parse_args "$@"

# removing repeated elements
DIR=$(echo "$DIR" | tr ' ' '\n' | sort -u | tr '\n' ' ')

# Trying running trivy binary first
if which trivy > /dev/null; then
    # Downloading last definitions
    trivy image --download-db-only

    trivy_bin=1
    trivy_scan

else
    echo -e "${RED}Trivy binary not found!${ENDCOLOR}"
    echo -e "${BLUE}Trying to run trivy docker image...${ENDCOLOR}"

    trivy_bin=0
    trivy_scan
fi
