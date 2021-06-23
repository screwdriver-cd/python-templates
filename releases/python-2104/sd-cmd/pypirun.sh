#!/usr/bin/env bash
# Copyright 2021, Oath Inc.
# Licensed under the terms of the BSD 3 Clause license. See LICENSE file in project root for terms.
# This script bootstraps the pypirun command line utility.
#
# This command will handle bootstrapping the following:
# - A python 3.x interpreter
# - The Python package manager utility (pip)
# - The ouroath.pypirun utility
#
# Once everything is bootstrapped, it will run the pypirun command line utility
# passing all command line arguments to it.
#
# The bootstrapping code can bootstrap Redhat/Fedora/Centos, Debian/Ubuntu
# and Alpine environments.

set -e
export PATH=$PATH:/opt/python/bin:~/.local/bin
export PYPIRUN_LOGFILE="$SD_ARTIFACTS_DIR/logs/sd-cmd/pypirun.log"
if [ ! -e "$SD_ARTIFACTS_DIR/logs/sd-cmd" ]; then
    mkdir -p "$SD_ARTIFACTS_DIR/logs/sd-cmd"
fi

function bootstrap_pypirun {
    set +e
    if [ "$BASE_PYTHON" != "" ]; then
        $BASE_PYTHON -c "import pypirun" > /dev/null 2>&1
        RC="$?"
    fi
    set -e
    if [ "$RC" = "0" ]; then
        return
    fi
    sd-cmd exec python-2104/python_bootstrap@stable >> $PYPIRUN_LOGFILE 2>&1
    source /tmp/python_bootstrap.env||/bin/true

}

function determine_pyrun_command {
    set +e
    if [ "$BASE_PYTHON" != "" ]; then
        $BASE_PYTHON -c "import pypirun" > /dev/null 2>&1
        RC="$?"
        if [ "$RC" = "0" ]; then
            PYPIRUN_COMMAND="$BASE_PYTHON -m pypirun"
        fi
    fi
    if [ "$PYRUN_COMMAND" = "" ]; then
        PYRUN_COMMAND="`which pypirun 2>&1`"
    fi
    set -e
    if [ "$PYRUN_COMMAND" = "" ]; then
        if [ -e "~/.local/bin/pypirun" ]; then
            PYRUN_COMMAND="~/.local/bin/pypirun"
        fi
    fi
    if [ "$PYRUN_COMMAND" = "" ]; then
        PYPIRUN_COMMAND="pypirun"
    fi    
}

bootstrap_pypirun
determine_pyrun_command
$PYRUN_COMMAND $@
