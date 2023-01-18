#! /usr/bin/env bash

for cmd in $(find /opt -type f -name post-start-command.sh ! -wholename $0); do
    . $cmd;
done
