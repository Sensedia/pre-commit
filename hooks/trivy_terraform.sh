#!/bin/env bash
#

set -eo pipefail

# Get list of modified terraform modules
TF_DIR="$(dirname "${@}" | uniq)"

# Run trivy against modified terraform modules
for dir in $TF_DIR; do

    # Trying running trivy binary first
    if [[ $(which trivy) ]]; then
        # Downloading last definitions
        trivy image --download-db-only
        trivy config --severity MEDIUM,HIGH,CRITICAL --exit-code 1 "$dir"
    else
        # Running trivy docker image
        docker run --rm -v "$PWD:/src:rw,Z" -w "/src" aquasec/trivy:0.44.0 config --severity MEDIUM,HIGH,CRITICAL --cache-dir /src/.pre-commit-trivy-cache --exit-code 1 "$dir"
    fi

done
