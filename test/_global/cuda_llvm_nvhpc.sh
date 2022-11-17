#! /usr/bin/env bash

# The 'test/_global' folder is a special test folder that is not tied to a single feature.
#
# This test file is executed against a running container constructed
# from the value of 'color_and_hello' in the tests/_global/scenarios.json file.
#
# The value of a scenarios element is any properties available in the 'devcontainer.json'.
# Scenarios are useful for testing specific options in a feature, or to test a combination of features.
#
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only .

set -ex

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

>&2 echo "NVHPC=$NVHPC"
>&2 echo "NVHPC_ROOT=$NVHPC_ROOT"
>&2 echo "NVHPC_VERSION=$NVHPC_VERSION"
>&2 echo "NVHPC_CUDA_HOME=$NVHPC_CUDA_HOME"
>&2 echo "NVHPC_MODULEPATH=$NVHPC_MODULEPATH"
ls -all "$NVHPC_ROOT"/ 1>&2

>&2 echo "BASH_ENV=$BASH_ENV"
>&2 echo "PATH=$PATH"
module use "$NVHPC_MODULEPATH"
module list 1>&2

# Check CUDA
CUDA_VERSION="$(\
    apt policy cuda-compiler-11-8 2>/dev/null \
  | grep -E 'Candidate: (.*).*$' - \
  | cut -d':' -f2 \
  | cut -d'-' -f1)";

check "version" echo "$CUDA_VERSION" | grep '11.8.0'
check "installed" stat /usr/local/cuda-11.8 /usr/local/cuda
check "nvcc exists and is on path" which nvcc

# Check LLVM
check "version" grep "llvm-toolchain-$(lsb_release -cs) main" /etc/apt/sources.list{,.d/*.list}

# Check NVHPC
check "version" echo "$NVHPC_VERSION" | grep '22.9'
check "installed" stat /opt/nvidia/hpc_sdk
check "nvc++ exists and is on path" which nvc++

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
