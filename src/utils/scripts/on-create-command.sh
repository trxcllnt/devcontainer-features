#! /usr/bin/env bash

for cmd in $(find /opt -type f -name on-create-command.sh ! -wholename $0); do
    . $cmd;
done
