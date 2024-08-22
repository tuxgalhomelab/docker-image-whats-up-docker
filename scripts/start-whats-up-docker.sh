#!/usr/bin/env bash
set -E -e -o pipefail

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

start_whats_up_docker () {
    source ${NVM_DIR:?}/nvm.sh

    echo "Starting What's Up Docker ..."
    echo

    cd /opt/whats-up-docker
    exec node index | ./node_modules/.bin/bunyan --time local --output long
}

set_umask
start_whats_up_docker
