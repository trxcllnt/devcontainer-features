#! /usr/bin/env bash
set -ex

nvhpc_ver=${NVHPCVERSION/./-}

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y;
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        echo "Installing prerequisites: $@";
        DEBIAN_FRONTEND=noninteractive \
        apt-get -y install --no-install-recommends "$@"
    fi
}

check_packages                  \
    gpg                         \
    lmod                        \
    wget                        \
    dpkg-dev                    \
    apt-utils                   \
    lsb-release                 \
    bash-completion             \
    ca-certificates             \
    apt-transport-https         \
    software-properties-common  \
    ;

echo "Downloading NVHPC gpg key...";

wget -O - https://developer.download.nvidia.com/hpc-sdk/ubuntu/DEB-GPG-KEY-NVIDIA-HPC-SDK \
   | gpg --dearmor -o /etc/apt/trusted.gpg.d/nvidia-hpcsdk-archive-keyring.gpg

chmod 0644 /etc/apt/trusted.gpg.d/*.gpg || true;

echo "Adding NVHPC SDK apt repository..."

# Install NVHPC-SDK apt repository
apt-add-repository -y "deb https://developer.download.nvidia.com/hpc-sdk/ubuntu/$(dpkg-architecture -q DEB_BUILD_ARCH) /";

echo "Installing NVHPC SDK..."

DEBIAN_FRONTEND=noninteractive              \
apt-get install -y --no-install-recommends  \
    nvhpc-${nvhpc_ver}                      \
    ;

nvhpc_ver=${NVHPCVERSION}

NVHPC="/opt/nvidia/hpc_sdk"
NVHPC_VERSION="${nvhpc_ver}"
NVHPC_ROOT="${NVHPC}/Linux_$(uname -p)/${nvhpc_ver}"
NVHPC_CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"

bash "${NVHPC_ROOT}/compilers/bin/makelocalrc" \
    -x "${NVHPC_ROOT}/compilers/bin" \
    -gcc "$(which gcc)" \
    -gpp "$(which g++)" \
    -g77 "$(which gfortran)"

# Install NVHPC modules
rm -rf /usr/share/lmod/lmod/modulefiles;
ln -sf "${NVHPC_ROOT}/comm_libs/hpcx/latest/modulefiles" /usr/share/lmod/lmod/modulefiles;

mkdir -p /etc/profile.d

cat <<EOF >> /etc/profile.d/z-nvhpc.sh
export NVHPC="${NVHPC}";
export NVHPC_ROOT="${NVHPC_ROOT}";
export NVHPC_VERSION="${NVHPC_VERSION}";
export NVHPC_CUDA_HOME="${NVHPC_CUDA_HOME}";

module use "\${NVHPC}/modulefiles";
module use "\${NVHPC_ROOT}/comm_libs/hpcx/latest/modulefiles";
module try-load nvhpc-nompi/\${NVHPC_VERSION};
module try-load nvhpc-nompi;
module try-load hpcx-mt;
module try-load hpcx;
EOF

chmod +x /etc/profile.d/z-nvhpc.sh

cat <<EOF > /etc/bash.bash_env
#! /usr/bin/env bash

# Make non-interactive/non-login shells behave like interactive login shells
if ! shopt -q login_shell; then
    if [ -f /etc/profile ]; then
        . /etc/profile
    fi
    for x in \$HOME/.{bash_profile,bash_login,profile}; do
        if [ -f \$x ]; then
            . \$x
            break
        fi
    done
fi
EOF

chmod +x /etc/bash.bash_env

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/*;
