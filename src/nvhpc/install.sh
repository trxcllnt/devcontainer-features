#! /usr/bin/env bash
set -ex

nvhpc_ver=${NVHPCVERSION/./-}

echo "Installing NVHPC prerequisites...";

apt update;

DEBIAN_FRONTEND=noninteractive         \
apt install -y --no-install-recommends \
    gpg                                \
    lmod                               \
    wget                               \
    apt-utils                          \
    lsb-release                        \
    ca-certificates                    \
    apt-transport-https                \
    software-properties-common         \
    ;

echo "Downloading NVHPC gpg key...";

wget -O - https://developer.download.nvidia.com/hpc-sdk/ubuntu/DEB-GPG-KEY-NVIDIA-HPC-SDK \
   | gpg --dearmor -o /etc/apt/trusted.gpg.d/nvidia-hpcsdk-archive-keyring.gpg

chmod 0644 /etc/apt/trusted.gpg.d/*.gpg || true;

echo "Adding NVHPC SDK apt repository..."

# Install NVHPC-SDK apt repository
apt-add-repository -y "deb https://developer.download.nvidia.com/hpc-sdk/ubuntu/$(dpkg-architecture -q DEB_BUILD_ARCH) /";

echo "Installing NVHPC SDK..."

DEBIAN_FRONTEND=noninteractive          \
apt install -y --no-install-recommends  \
    nvhpc-${nvhpc_ver}                  \
    ;

nvhpc_ver=${NVHPCVERSION}

export NVHPC="/opt/nvidia/hpc_sdk"
export NVHPC_VERSION="${nvhpc_ver}"
export NVHPC_ROOT="${NVHPC}/Linux_$(uname -m)/${nvhpc_ver}"
export NVHPC_CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
export MODULEPATH="${NVHPC}/modulefiles:${NVHPC_ROOT}/comm_libs/hpcx/latest/modulefiles"

bash "${NVHPC_ROOT}/compilers/bin/makelocalrc" \
    -x "${NVHPC_ROOT}/compilers/bin" \
    -gcc "$(which gcc)" \
    -gpp "$(which g++)" \
    -g77 "$(which gfortran)"

# Install NVHPC modules
rm -rf /usr/share/lmod/lmod/modulefiles;
ln -sf "${NVHPC_ROOT}/comm_libs/hpcx/latest/modulefiles" /usr/share/lmod/lmod/modulefiles;

cat <<EOF2 > /etc/profile.d/z-nvhpc-modules.sh
#! /usr/bin/env bash
module try-load nvhpc-nompi/${NVHPC_VERSION};
module try-load hpcx-mt;
module try-load hpcx;
EOF2

chmod +x /etc/profile.d/z-nvhpc-modules.sh;

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/*;
