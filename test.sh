#!/bin/bash

image=mcr.microsoft.com/devcontainers/base:ubuntu

# for feature in \
#                `# cuda`  \
#                llvm  \
#                `# nvhpc` ; do
#     npx --package=@devcontainers/cli -c "devcontainer features test -f $feature -i $image .";
# done

npx --package=@devcontainers/cli -c "devcontainer features test --global-scenarios-only";
