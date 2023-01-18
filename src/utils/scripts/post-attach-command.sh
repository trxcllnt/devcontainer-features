#! /usr/bin/env bash

set -euo pipefail;

. /opt/devcontainer/bin/git/init.sh;
/opt/devcontainer/bin/vault/s3/init.sh;

for cmd in $(find /opt -type f -name post-attach-command.sh ! -wholename $0); do
    . $cmd;
done
