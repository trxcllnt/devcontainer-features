#! /usr/bin/env bash

. /opt/devcontainer/bin/git/init.sh || exit $?;
. /opt/devcontainer/bin/vault/s3/init.sh || exit $?;

for cmd in $(find /opt -type f -name post-attach-command.sh ! -wholename $0); do
    . $cmd;
done
