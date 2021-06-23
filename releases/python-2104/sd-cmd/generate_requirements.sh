#!/usr/bin/env bash
# Copyright 2021, Oath Inc.
# Licensed under the terms of the Apache 2.0 license.  See the LICENSE file in the project root for terms

# Bootstrap python
export PYTHON_BOOTSTRAP_SKIP_SCREWDRIVERCD="True"
sd-cmd exec python-2104/python_bootstrap@pre
. /tmp/python_bootstrap.env

if [ "${GEN_REQUIREMENTS_SRC_FILES}" = "" ]; then
    if [ -e "requirements.in" ]; then
        GEN_REQUIREMENTS_SRC_FILES="requirements.in"
    fi
fi

${BASE_PYTHON_BIN}/pypirun pip-tools pip-compile -o requirements.txt --generate-hashes --allow-unsafe ${GEN_REQUIREMENTS_SRC_FILES}

mkdir -p "${SD_ARTIFACTS_DIR}/config"
cp requirements.txt "${SD_ARTIFACTS_DIR}/config"
