#! /usr/bin/env bash
set -ex

echo "Installing CUDA prerequisites...";

apt update;

DEBIAN_FRONTEND=noninteractive          \
apt install -y --no-install-recommends  \
    wget ca-certificates                \
    ;

echo "Downloading CUDA keyring...";

nv_arch="$(uname -m)";

if [[ "$nv_arch" == aarch64 ]]; then
    nv_arch="sbsa";
fi

cd "$(mktemp -d)";

# Add NVIDIA's keyring and apt repository
wget "\
https://developer.download.nvidia.com/compute/cuda/repos/\
$(. /etc/os-release; echo "$ID${VERSION_ID/./}")/\
${nv_arch}/cuda-keyring_1.0-1_all.deb"

dpkg -i cuda-keyring_1.0-1_all.deb;

apt update;

echo "Installing minimal CUDA toolkit..."

cuda_ver=${CUDAVERSION/./-}

DEBIAN_FRONTEND=noninteractive          \
apt install -y --no-install-recommends  \
    libnccl-dev                         \
    gds-tools-${cuda_ver}               \
    cuda-compat-${cuda_ver}             \
    cuda-nvml-dev-${cuda_ver}           \
    cuda-compiler-${cuda_ver}           \
    cuda-libraries-${cuda_ver}          \
    cuda-libraries-dev-${cuda_ver}      \
    cuda-minimal-build-${cuda_ver}      \
    cuda-command-line-tools-${cuda_ver} \
    ;

if [[ ! -L $CUDA_HOME ]]; then
    # Create /usr/local/cuda symlink
    ln -s "$CUDA_HOME-${CUDAVERSION}" "$CUDA_HOME";
fi

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/*;
