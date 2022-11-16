#! /usr/bin/env bash

# This test can be run with the following command (from the root of this repo)
# ```
# npx --package=@devcontainers/cli -c 'devcontainer features test \
#     --features nvhpc \
#     --base-image mcr.microsoft.com/devcontainers/base:ubuntu .'
# ```

set -ex

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "version" echo $NVHPC_VERSION | grep '22.9'
check "installed" stat /opt/nvidia/hpc_sdk
check "nvc++ exists and is on path" which nvc++

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
