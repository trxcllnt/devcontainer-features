#! /usr/bin/env bash

for cmd in $(find /opt -type f -name update-content-command.sh ! -wholename $0); do
    . $cmd;
done
