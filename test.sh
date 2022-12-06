#!/bin/bash

images=()
images+=("ubuntu:jammy")
images+=("mcr.microsoft.com/devcontainers/base:ubuntu")

for image in $images; do
    features=()
    features+=("cmake")
    features+=("cuda")
    features+=("llvm")
    features+=("ninja")
    features+=("nvhpc")
    features+=("sccache")
    for feature in $features; do
        npx --package=@devcontainers/cli -c "\
            devcontainer features test \
                --skip-scenarios \
                --log-level trace \
                -f $feature \
                -i $image \
                -p .";
    done
done

npx --package=@devcontainers/cli -c "devcontainer features test --log-level trace --global-scenarios-only";
