#!/usr/bin/env bash
# Copyright 2021, Oath Inc.
# Licensed under the terms of the Apache 2.0 license.  See the LICENSE file in the project root for terms

set -e

if [ "${SD_ARTIFACTS_DIR}" = "" ]; then
    SD_ARTIFACTS_DIR="artifacts"
fi

if [ ! -e "$SD_ARTIFACTS_DIR/logs/sd-cmd" ]; then
    mkdir -p "$SD_ARTIFACTS_DIR/logs/sd-cmd"
fi

if [ ! -e "$SD_ARTIFACTS_DIR/env" ]; then
    mkdir -p "$SD_ARTIFACTS_DIR/env"
fi

export DISTROENV_LOGFILE="$SD_ARTIFACTS_DIR/logs/sd-cmd/distroenv.log"
export DISTROENV="$SD_ARTIFACTS_DIR/env/distro.env"

function log_message {
    echo "$1" >> $DISTROENV_LOGFILE
}

function log_header {
    log_message "### $1"
}

function bootstrap_python_if_missing {
    log_header "Bootstrapping Python if missing"
    if [ -e "$BASE_PYTHON" ]; then
        log_message "Using existing Python at $BASE_PYTHON"
        return
    fi

    log_message "Bootstrapping Python"
    sd-cmd exec python-2104/python_bootstrap@stable >> $DISTROENV_LOGFILE 2>&1
    source /tmp/python_bootstrap.env||/bin/true
}

function install_distro {
    $BASE_PYTHON -m pip install distro >> $DISTROENV_LOGFILE 2>&1
}

function get_distro_values {
    $BASE_PYTHON << EOF
import os
import distro

outfilename = os.environ.get('DISTROENV', 'distro.env')
with open(outfilename, 'w') as outfile:
    outfile.write(f'''DISTRO_BUILD_NUMBER="{distro.build_number()}"
DISTRO_CODENAME="{distro.codename()}"
DISTRO_ID="{distro.id()}"
DISTRO_LINUX_DISTRIBUTION="{distro.linux_distribution()}"
DISTRO_LIKE="{distro.like()}"
DISTRO_MAJOR_VERSION="{distro.major_version()}"
DISTRO_MINOR_VERSION="{distro.minor_version()}"
DISTRO_NAME="{distro.name()}"
DISTRO_VERSION="{distro.version()}"
export DISTRO_CODENAME DISTRO_ID DISTRO_LINUX_DISTRIBUTION DISTRO_LIKE DISTRO_MAJOR_VERSION
export DISTRO_MINOR_VERSION DISTRO_NAME DISTRO_VERSION
''')
EOF
    log_message "Distro env filename is: $DISTROENV"
    log_message "Distro env file contents"
    cat $DISTROENV >> $DISTROENV_LOGFILE
    . $DISTROENV
}

bootstrap_python_if_missing
install_distro
get_distro_values
echo "$DISTROENV"
