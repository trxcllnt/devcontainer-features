#! /usr/bin/env bash
set -ex

# Install Devcontainer utility scripts to /opt/devcontainer
FEATURE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
mkdir -p /opt/devcontainer;
cp -ar ${FEATURE_DIR}/scripts /opt/devcontainer/bin;

find /opt/devcontainer \
    \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; \
    -o -type f -exec chmod u+rw,g+rw,o+r {} \; \)

find /opt/devcontainer -type f -exec chmod +x {} \;

if dpkg -s bash-completion 2>&1 >/dev/null; then
    if type gh 2>&1 >/dev/null; then
        gh completion -s bash | tee /etc/bash_completion.d/gh >/dev/null;
    fi
    if type glab 2>&1 >/dev/null; then
        glab completion -s bash | tee /etc/bash_completion.d/glab >/dev/null;
    fi
fi
