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
ls -all "$NVHPC_ROOT"/ 1>&2

>&2 echo "BASH_ENV=$BASH_ENV"
>&2 echo "PATH=$PATH"
module list 1>&2

# Check CMake
CMAKE_VERSION="3.25.1";
check "cmake exists and is on path" which cmake
check "version" bash -c "cmake --version | grep '$CMAKE_VERSION'"

# Check CUDA
CUDA_VERSION="$(\
    apt policy cuda-compiler-11-8 2>/dev/null \
  | grep -E 'Candidate: (.*).*$' - \
  | cut -d':' -f2 \
  | cut -d'-' -f1)";

check "version" bash -c "echo '$CUDA_VERSION' | grep '11.8.0'"
check "installed" stat /usr/local/cuda-11.8 /usr/local/cuda
check "nvcc exists and is on path" which nvcc

# Check LLVM
echo "LLVM_VERSION: $LLVM_VERSION"
check "clang version" bash -c "clang --version | grep 'clang version $LLVM_VERSION'"
check "apt repo" grep "llvm-toolchain-$(lsb_release -cs) main" /etc/apt/sources.list{,.d/*.list}

# Check Mambaforge
check "conda exists and is on path" which conda
check "mamba exists and is on path" which mamba

conda --version
mamba --version

# Check ninja
NINJA_VERSION="1.11.1";
check "ninja exists and is on path" which ninja
check "version" bash -c "ninja --version | grep '$NINJA_VERSION'"

# Check NVHPC
check "version" bash -c "echo '$NVHPC_VERSION' | grep '22.11'"
check "installed" stat /opt/nvidia/hpc_sdk
check "nvc++ exists and is on path" which nvc++

# Check sccache
SCCACHE_VERSION="0.3.1";
check "sccache exists and is on path" which sccache
check "version" bash -c "sccache --version | grep '$SCCACHE_VERSION'"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
