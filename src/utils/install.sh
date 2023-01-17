#! /usr/bin/env bash
set -ex

# Install Devcontainer utility scripts to /opt/devcontainer
FEATURE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
mkdir -p /opt/devcontainer;
cp -ar ${FEATURE_DIR}/scripts /opt/devcontainer/bin;

find /opt/devcontainer \
    \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; \
    -o -type f -exec chmod u+rw,g+rw,o+r {} \; \)
