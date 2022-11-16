#!/bin/bash

image=mcr.microsoft.com/devcontainers/base:ubuntu

for feature in cuda llvm nvhpc ; do
npx --package=@devcontainers/cli -c "\
    devcontainer features test \
        --skip-scenarios --log-level trace -f $feature -i $image -p .";
done

npx --package=@devcontainers/cli -c "devcontainer features test --log-level trace --global-scenarios-only";
