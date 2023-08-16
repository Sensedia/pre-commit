#!/bin/env bash
#
# shellcheck disable=SC2086 # allow to pass arguments as a string

set -eo pipefail

# color
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
ENDCOLOR='\033[0m'

# files to control scanning
trivy_ignorefile=".trivyignore"

# Validate Dependencies
function validate_dependencies() {
    if ! command -v trivy &> /dev/null && ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Neither 'trivy' binary or 'docker' found!${ENDCOLOR}"
        exit 1
    fi
}

# Parsing arguments
function parse_args() {
    local -r args=("$@")

    for arg in "${args[@]}"; do

        if [[ -f $arg || -d $arg ]]; then
            DIR+=" $(realpath "$(dirname "$arg")")"
        else
            ARGS+=" $arg"
        fi
    done

    # Remove spaces in beginning of string
    DIR=${DIR# }
    ARGS=${ARGS# }

}

function test_terragrunt_file() {
    local dir="$1"
    local check_login

    cd "$dir"
    if terragrunt terragrunt-info &> /dev/null; then
        return 0
    else
        check_login=$(terragrunt terragrunt-info 2>&1)
        if grep -qi "backend initialization" <<< "$check_login"; then
            echo -e "${RED}Error: Check if you're logged in on the account account!${ENDCOLOR}"
            exit 1
        else
            return 1
        fi
    fi
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

    for dir in $1; do

        # Testing terragrunt file
        if test_terragrunt_file "$dir"; then
            cd "$dir"
            terragrunt plan -out=tfplan.binary --terragrunt-non-interactive > /dev/null
            TG_CACHE_DIR=$(find "$dir" -type d -name '.terraform' -exec dirname {} \+)
            cd "$TG_CACHE_DIR"
            terraform show -json tfplan.binary > tfplan.json

        else
            continue
        fi

        echo -e "\n---------------------------------------"
        echo "SCANNING -> $dir"
        echo -e "---------------------------------------\n"

        # check if ignorefile exists
        if [[ -f "$dir/$trivy_ignorefile" ]]; then
            ARGS+=" --ignorefile $dir/$trivy_ignorefile"
        fi

        if [[ $trivy_bin -eq 1 ]]; then
            trivy config ${ARGS} "$TG_CACHE_DIR/tfplan.json"

            # remove plan files
            rm -rf "$TG_CACHE_DIR/tfplan.binary" "$TG_CACHE_DIR/tfplan.json"
        else
            docker run --rm -v "$PWD:/src:rw,Z" -w "/src" aquasec/trivy:latest config \
                --cache-dir /src/.pre-commit-trivy-cache \
                ${ARGS} "$TG_CACHE_DIR/tfplan.json"

        fi

        echo -e "\n${GREEN}No Problems Found!!!${ENDCOLOR}"
    done

}

function main() {
    validate_dependencies
    parse_args "$@"
    DIR=$(echo "$DIR" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    trivy_scan "$DIR"
}

main "$@"
