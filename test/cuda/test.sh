#! /usr/bin/env bash

# This test can be run with the following command (from the root of this repo)
# ```
# npx --package=@devcontainers/cli -c 'devcontainer features test \
#     --features cuda \
#     --base-image mcr.microsoft.com/devcontainers/base:ubuntu .'
# ```

set -ex

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

cat "$HOME/.bashrc"

source "$HOME/.bashrc"

echo "$PATH"

CUDA_VERSION="$(\
    apt policy cuda-compiler-11-8 2>/dev/null \
  | grep -E 'Candidate: (.*).*$' - \
  | cut -d':' -f2 \
  | cut -d'-' -f1)";

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "version" echo "$CUDA_VERSION" | grep '11.8.0'
check "installed" stat /usr/local/cuda-11.8 /usr/local/cuda
check "nvcc exists and is on path" which nvcc

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
