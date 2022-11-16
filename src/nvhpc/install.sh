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
    dpkg-dev                           \
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

NVHPC="/opt/nvidia/hpc_sdk"
NVHPC_VERSION="${nvhpc_ver}"
NVHPC_ROOT="${NVHPC}/Linux_$(uname -m)/${nvhpc_ver}"
NVHPC_CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
MODULEPATH="${NVHPC}/modulefiles:${NVHPC_ROOT}/comm_libs/hpcx/latest/modulefiles"

bash "${NVHPC_ROOT}/compilers/bin/makelocalrc" \
    -x "${NVHPC_ROOT}/compilers/bin" \
    -gcc "$(which gcc)" \
    -gpp "$(which g++)" \
    -g77 "$(which gfortran)"

# Install NVHPC modules
rm -rf /usr/share/lmod/lmod/modulefiles;
ln -sf "${NVHPC_ROOT}/comm_libs/hpcx/latest/modulefiles" /usr/share/lmod/lmod/modulefiles;

cat <<EOF > /etc/profile.d/z-nvhpc-modules.sh
#! /usr/bin/env bash
module try-load nvhpc-nompi/${NVHPC_VERSION};
module try-load hpcx-mt;
module try-load hpcx;
EOF

for x in {/etc/skel,${_CONTAINER_USER_HOME}}/.bashrc; do
    cat <<EOF >> $x
export NVHPC="${NVHPC}";
export NVHPC_ROOT="${NVHPC_ROOT}";
export NVHPC_VERSION="${NVHPC_VERSION}";
export NVHPC_CUDA_HOME="${NVHPC_CUDA_HOME}";
export MODULEPATH="${MODULEPATH}";
EOF
done

chmod +x /etc/profile.d/z-nvhpc-modules.sh;

cat <<EOF > "/etc/bash_env"
#! /usr/bin/env bash

# Make non-interactive/non-login shells behave like interactive login shells
if ! shopt -q login_shell; then
    if [ -f /etc/profile ]; then
        . /etc/profile
    fi
    for x in $HOME/.{bash_profile,bash_login,profile}; do
        if [ -f $x ]; then
            . $x
            break
        fi
    done
fi
EOF

chmod +x /etc/bash_env

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/*;
