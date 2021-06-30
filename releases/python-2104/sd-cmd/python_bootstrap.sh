#!/usr/bin/env sh
# Copyright 2021, Oath Inc.
# Licensed under the terms of the Apache 2.0 license.  See the LICENSE file in the project root for terms

# setup_environment
PATH=/opt/python/cp39-cp39/bin:/opt/python/cp38-cp38/bin:/opt/python/cp37-cp37m/bin:/opt/python/cp36-cp36m/bin:$PATH
export PATH
PIP_PKG_URL="https://pypi.org/packages/36/74/38c2410d688ac7b48afa07d413674afc1f903c1c1f854de51dc8eb2367a5/pip-20.2-py2.py3-none-any.whl#sha256=d75f1fc98262dabf74656245c509213a5d0f52137e40e8f8ed5cc256ddd02923"
export PIP_PKG_URL

header() {
    echo
    echo "################################################################"
    echo "$@"
    echo "################################################################"
}

subheader() {
    echo
    echo "## $*"
}

resolv_filename() {
    ORIG_PATH="$1"
    FULL_PATH="$1"
    if [ -e "/usr/bin/readlink" ]; then
        FULL_PATH="`readlink $FULL_PATH`"
        if [ "$FULL_PATH" = "" ]; then
            FULL_PATH="$ORIG_PATH"
        fi
    fi
    echo "$FULL_PATH"
}

exit_if_python_version_not_supported() {
    if [ -e "/etc/os-release" ]; then
        . /etc/os-release
        if [ "$ID" = "debian" ]; then
            return
        fi
        if [ "$ID_LIKE" = "debian" ]; then
            return
        fi

        python_basename="$(basename $BASE_PYTHON)"
        python_version="${python_basename/python}"

        if [ "$python_version" = "3" ]; then
            return
        fi

        if [ "$ID" = "alpine" ]; then
            return
        fi

        distro_maj="$(echo $VERSION_ID|cut -d. -f 1)"
        distro_minor="$(echo $VERSION_ID|cut -d. -f 2)"
        python_maj="$(echo $python_version|cut -d. -f 1)"
        python_minor="$(echo $python_version|cut -d. -f 2)"
        if [ "${python_minor}" -gt "6" ]; then
            if [ "${distro_maj}" -lt "7" ]; then
                echo "ERROR: Python version $python_version is not supported on RHEL ${VERSION_ID}"
                exit 1
            fi
            if [ "${distro_maj}" = "7" ]; then
                if [ "${distro_minor}" -lt "7" ]; then
                    echo "ERROR: Python version $python_version is not supported on RHEL ${VERSION_ID}"
                    exit 1
                fi
            fi
        fi
    fi
}

# Determine if we need sudo, if we don't need sudo we don't want to use it because some containers sudo is not set
# up properly.
header Determining if sudo is required
SUDO_CMD="sudo "
USER_ID=`id -u`
if [ "${USER_ID}" = "0" ]; then
    echo "Sudo is not required"
    SUDO_CMD=""
else
    echo "Sudo is required"
fi

header "Ensuring the TERM env variable is sane"
if [ "$TERM" = "" ]; then
    echo "TERM is not set, setting to ansi"
    export TERM="ansi"
fi

header "Checking if a sane Python interpreter is already installed"
if [ "$BASE_PYTHON" = "" ]; then
    echo "BASE_PYTHON is not set, setting BASE_PYTHON=python3"
    BASE_PYTHON="python3"
fi

BINDIR="`dirname ${BASE_PYTHON} 2>/dev/null`"
export BINDIR
if [ "$BINDIR" != "" ]; then
    export PATH="${BINDIR}:${PATH}"
fi

# init_os
ORIG_BASE_PYTHON="$BASE_PYTHON"
PYTHON=`basename $BASE_PYTHON 2>/dev/null|sed "s/\.//"`
BASE_PYTHON_BASENAME="`basename $BASE_PYTHON 2>/dev/null`"

if [ "$BASE_PYTHON_BASENAME" = "" ]; then
    BASE_PYTHON_BASENAME="python3"
fi

if [ -z "$BASE_PYTHON" ]; then
    echo "BASE_PYTHON is not set, looking for a working python3 interpreter"
    # No BASE_PYTHON declared, see if there is a working python3 interpreter in the path
    python3 -m venv --help > /dev/null 2>&1
    RC="$?"
    if [ "$RC" = "0" ]; then
        BASE_PYTHON="`$BASE_PYTHON_BASENAME -c "import sys;print(sys.executable)"`"
        if [ -e "/usr/bin/readlink" ]; then
            BASE_PYTHON="`readlink ${FULL_BASE_PYTHON}`"
        fi
        export BASE_PYTHON
        echo "Found working python interpreter: $BASE_PYTHON"
    fi
else
    if [ ! -e "$BASE_PYTHON" ]; then
        echo "Interpreter specified by BASE_PYTHON is not the full path, trying to use it to find the full path"
        BASE_PYTHON_BASENAME="python3"
        FULL_BASE_PYTHON="`$BASE_PYTHON -c "import pip,sys,venv;print(sys.executable)" 2>/dev/null`"
        RC="$?"
        if [ "$RC" = "0" ]; then
            echo "Working interpreter $FULL_BASE_PYTHON found"
            BASE_PYTHON="$FULL_BASE_PYTHON"
        else
            echo "Interpreter $FULL_BASE_PYTHON is not functional"
            BASE_PYTHON="python3"
        fi
    fi
fi

if [ ! -e "$BASE_PYTHON" ]; then
    header "Working Python interpreter not found"

    subheader "Checking if the OS supports the specified version of Python"
    exit_if_python_version_not_supported

    header "Attempting to install an interpreter"
    if [ -e "/usr/bin/apt-get" ]; then
        header "Installing debian/ubuntu python"
        subheader "Updating the apt package list"
        ${SUDO_CMD} apt-get update

        subheader "Installing ${PYTHON} ${PYTHON}-venv ${PYTHON}-pip python3-venv python3-pip"
        ${SUDO_CMD} apt-get install -y ${PYTHON} ${PYTHON}-venv ${PYTHON}-pip python3-venv python3-pip
    fi

    if [ -e "/sbin/apk" ]; then
        header "Installing Alpine python"
        if [ "$BASE_PYTHON" != "" ]; then
            python_basename="$(basename $BASE_PYTHON)"
            python_short_version="$(echo $python_basename|sed "s/^python//g"|cut -b1-3)"
            if [ "$python_short_version" = "" ]; then
                python_short_version="$python_basename"
            fi
            python_version="${python_short_version}.0"
        else
            python_short_version="3.6"
            python_version="3.6.0"
        fi
        if [ "$BASE_PYTHON" = "python3" ]; then
            python_short_version="3.6"
            python_version="3.6.0"
        fi
        echo
        ${SUDO_CMD} apk --upgrade add "python3>$python_version" python3-dev py3-pip py3-cffi py3-cparser py3-openssl py3-lxml gcc musl-dev libc-dev libffi libffi-dev libxml2-dev libxslt-dev make openssl openssl-dev ca-certificates
        RC="$?"
        if [ "$RC" != "0" ]; then
            subheader "Unable to install python${python_short_version}, updating the package index and retrying"
            ${SUDO_CMD} apk update
            ${SUDO_CMD} apk --upgrade add "python3>$python_version" python3-dev py3-pip py3-cffi py3-cparser py3-openssl py3-lxml gcc musl-dev libc-dev libffi libffi-dev libxml2-dev libxslt-dev make openssl openssl-dev ca-certificates
            RC="$?"
            if [ "$RC" != "0" ]; then
                subheader "Unable to install python${python_short_version}"
                exit $RC
            fi
        fi
        BASE_PYTHON_BIN="/usr/bin"
        BASE_PYTHON_BASENAME="`readlink /usr/bin/python3`"

        BASE_PYTHON="$BASE_PYTHON_BIN/$BASE_PYTHON_BASENAME"
        subheader "Updated base python to $BASE_PYTHON"

        python_interpreter_version=$(python3 --version)
        python_interpreter_short_version=$(echo $python_interpreter_version|awk '{print $2}'|cut -b1-3)

        if [ "$python_short_version" != "$python_interpreter_short_version" ]; then
            subheader "WARNING: The $python_short_version interpreter version does not match the current alpine interpreter version of $python_interpreter_short_version"
        fi

        subheader "Making sure the $BASE_PYTHON interpreter pip module works"
        RC="0";
        $BASE_PYTHON -m pip help > /dev/null 2>&1
        RC="$?"
        if [ "$RC" != "0" ]; then
            subheader "Unable to install a working python interpreter"
            exit $RC
        fi
    fi

    if [ -e "/usr/bin/yum" ]; then
        header "Installing CentOS/Fedora/RHEL/yLinux python"
        if [ "$ORIG_BASE_PYTHON" != "" ]; then
            BASE_PYTHON_BASENAME="`basename $ORIG_BASE_PYTHON 2>/dev/null`"
        fi
        subheader "Python 3.x interpreter $BASE_PYTHON_BASENAME is not found"
        ${SUDO_CMD} yum makecache fast || true

        subheader "Attempting to installing redhat/fedora python3"
        ${SUDO_CMD} yum install -y python3 python3-devel python3-pip
        ${SUDO_CMD} /usr/bin/python3 -m pip install -U pip
    fi

    $BASE_PYTHON -c "import sys;print(sys.executable)" > /dev/null 2>&1
    RC="$?"
    if [ "$RC" != "0" ]; then
        subheader "WARNING: Was unable to install the $BASE_PYTHON interpreter checking for a working $BASE_PYTHON_BASENAME interpreter somewhere else"
        $BASE_PYTHON_BASENAME -c "import sys;print(sys.executable)" > /dev/null 2>&1
        RC="$?"
        if [ "$RC" != "0" ]; then
            subheader "ERROR: Was unable to install a working $BASE_PYTHON_BASENAME interpreter on this operating system"
            exit 1
        fi
    fi
    BASE_PYTHON="`$BASE_PYTHON_BASENAME -c "import sys;print(sys.executable)"`"
    BASE_PYTHON="`resolv_filename $BASE_PYTHON`"
    subheader "Python package installed, BASE_PYTHON=$BASE_PYTHON"
fi

if [ -e "/usr/bin/apt-get" ]; then
    # Debian removes the pip package bundled in the Python interpreter ensurepip module and instead uses
    # the old pip command from the deb packages.  Which happens to have broken handling of multiple repo
    # configurations.
    # The following overwrites the broken pip with a version close to what is normally bundled with the Python
    # interpreter.
    # This is done using wget because if the pip configuration in the base container has multiple indexes it is
    # not possible to do this with the pip command.
    header "Replacing debian broken pip wheel package"
    if [ ! -e "/usr/bin/wget" ]; then
        ${SUDO_CMD} /usr/bin/apt-get install -y wget
    fi
    ${SUDO_CMD} wget -O /usr/share/python-wheels/pip-9.0.1-py2.py3-none-any.whl ${PIP_PKG_URL}
    ${SUDO_CMD} $BASE_PYTHON -m pip install -U pip
fi

BINDIR="`dirname ${BASE_PYTHON} 2>/dev/null`"
export BINDIR
if [ "$BINDIR" != "" ]; then
    if [ "$BINDIR" != "." ]; then
        export PATH="${BINDIR}:${PATH}"
    fi
fi

export BASE_PYTHON_BIN="${BINDIR}"

$BASE_PYTHON -c "import pip,sys;sys.exit(int(int(pip.__version__.split('.')[0])<21))" >/dev/null 2>&1
RC="$?"
if [ "$RC" != "0" ] || [ "$(echo $PYTHON_BOOTSTRAP_UPGRADE_PIP|tr '[:upper:]' '[:lower:]')" = "true" ]; then
    header "Updating the pip package"
    ${SUDO_CMD} $BASE_PYTHON -m pip install -U pip
fi

$BASE_PYTHON -c "import setuptools,sys;sys.exit(int(int(setuptools.__version__.split('.')[0])<40))" >/dev/null 2>&1
RC="$?"
if [ "$RC" != "0" ]; then
    header "Upgrading the setuptools package"
    ${SUDO_CMD} $BASE_PYTHON -m pip install -U setuptools
fi

if [ "$(echo $PYTHON_BOOTSTRAP_SKIP_PYPIRUN|tr '[:upper:]' '[:lower:]')" != "true" ]; then
    # install_pyrun
    $BASE_PYTHON -c "import pypirun" >/dev/null 2>&1
    RC="$?"
    if [ "$RC" != "0" ]; then
        header "Installing pypirun into interpreter $BASE_PYTHON"
        ${SUDO_CMD} $BASE_PYTHON -m pip install -q -U pypirun
    fi
fi

if [ "$(echo $PYTHON_BOOTSTRAP_SKIP_SCREWDRIVERCD|tr '[:upper:]' '[:lower:]')" != "true" ]; then
    # install_screwdrivercd
    $BASE_PYTHON -c "import screwdrivercd.utility" >/dev/null 2>&1
    RC="$?"
    if [ "$RC" != "0" ]; then
        header "Installing screwdrivercd into interpreter $BASE_PYTHON"
        ${SUDO_CMD} $BASE_PYTHON -m pip install -U --force-reinstall screwdrivercd
    fi
fi

if [ -e "/sbin/apk" ]; then
    if [ "$CRYPTOGRAPHY_DONT_BUILD_RUST" = "" ]; then
        subheader "Alpine: Enabling cryptography setting to disable rust extension build"
        CRYPTOGRAPHY_DONT_BUILD_RUST="1"
        export CRYPTOGRAPHY_DONT_BUILD_RUST
    fi
    if [ ! -e "/usr/bin/make" ]; then
        subheader "Alpine: Ensuring the make utility is installed"
        apk add make
    fi
fi

cat << EOF > /tmp/python_bootstrap.env
# Created by python_bootstrap sd-cmd
BINDIR="$BINDIR"
BASE_PYTHON="$BASE_PYTHON"
BASE_PYTHON_BIN="$BASE_PYTHON_BIN"
PIP_CMD="$BASE_PYTHON -m pip"
PATH="${BASE_PYTHON_BIN}:\$PATH:/opt/vz/1.0/bin:/opt/python/bin:${HOME}/.local/bin"
EOF

if [ "$CRYPTOGRAPHY_DONT_BUILD_RUST" != "" ]; then
    cat << EOF >> "/tmp/python_bootstrap.env"
CRYPTOGRAPHY_DONT_BUILD_RUST="$CRYPTOGRAPHY_DONT_BUILD_RUST"
EOF
fi

cat << EOF >> /tmp/python_bootstrap.env
export BASE_PYTHON
export BASE_PYTHON_BIN
export PIP_CMD
export PATH
EOF

if [ "$CRYPTOGRAPHY_DONT_BUILD_RUST" != "" ]; then
    cat << EOF >> "/tmp/python_bootstrap.env"
export CRYPTOGRAPHY_DONT_BUILD_RUST
EOF
fi


ART_DIR="${SD_ARTIFACTS_DIR}/env"
if [ ! -e "${ART_DIR}" ]; then
    mkdir "${ART_DIR}"
fi
cp /tmp/python_bootstrap.env "${ART_DIR}/python_bootstrap.env"

header Python bootstrap complete
echo "The installed environment configuration can be activated by running:"
echo "    source /tmp/python_bootstrap.env"
echo
echo "Python interpreter and PIP commands bootstrapped are in the BASE_PYTHON and BASE_PYTHON_PIP environment variables"
echo "    BASE_PYTHON=$BASE_PYTHON"
echo "    BASE_PYTHON_BIN=$BASE_PYTHON_BIN"
echo "    PIP_CMD=$BASE_PYTHON -m pip"
if [ "$CRYPTOGRAPHY_DONT_BUILD_RUST" != "" ]; then
    echo "    CRYPTOGRAPHY_DONT_BUILD_RUST=$CRYPTOGRAPHY_DONT_BUILD_RUST"
fi
