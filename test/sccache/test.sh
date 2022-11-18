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

SCCACHE_VERSION="$(wget -O- -q https://api.github.com/repos/mozilla/sccache/releases/latest | jq -r ".tag_name" | tr -d 'v')";

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "sccache exists and is on path" which sccache
check "version" sccache --version | grep "$SCCACHE_VERSION"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
