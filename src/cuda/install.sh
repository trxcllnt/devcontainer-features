#! /usr/bin/env bash
set -ex

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

check_packages wget ca-certificates bash-completion

echo "Downloading CUDA keyring...";

nv_arch="$(uname -p)";

if [[ "$nv_arch" == aarch64 ]]; then
    nv_arch="sbsa";
fi

cd "$(mktemp -d)";

# Add NVIDIA's keyring and apt repository
wget --no-hsts -q "\
https://developer.download.nvidia.com/compute/cuda/repos/\
$(. /etc/os-release; echo "$ID${VERSION_ID/./}")/\
${nv_arch}/cuda-keyring_1.0-1_all.deb"

dpkg -i cuda-keyring_1.0-1_all.deb;

apt-get update;

echo "Installing minimal CUDA toolkit..."

cuda_ver=${CUDAVERSION/./-}
gds_tools=
if [[ $(uname -p) == x86_64 ]]; then
    gds_tools="gds-tools-${cuda_ver}";
fi

DEBIAN_FRONTEND=noninteractive              \
apt-get install -y --no-install-recommends  \
    libnccl-dev                             \
    ${gds_tools}                            \
    cuda-compat-${cuda_ver}                 \
    cuda-nvml-dev-${cuda_ver}               \
    cuda-compiler-${cuda_ver}               \
    cuda-libraries-${cuda_ver}              \
    cuda-driver-dev-${cuda_ver}             \
    cuda-libraries-dev-${cuda_ver}          \
    cuda-minimal-build-${cuda_ver}          \
    cuda-command-line-tools-${cuda_ver}     \
    ;

if [[ ! -L /usr/local/cuda ]]; then
    # Create /usr/local/cuda symlink
    ln -s "/usr/local/cuda-${CUDAVERSION}" "/usr/local/cuda";
fi

cuda_ver=$(grep "#define CUDA_VERSION" /usr/local/cuda/include/cuda.h | cut -d' ' -f3);
CUDA_VERSION_MAJOR=$((cuda_ver / 1000));
CUDA_VERSION_MINOR=$((cuda_ver / 10 % 100));
CUDA_VERSION_PATCH=$((cuda_ver % 10));
CUDA_VERSION="$CUDA_VERSION_MAJOR.$CUDA_VERSION_MINOR.$CUDA_VERSION_PATCH";

# Required for nvidia-docker v1
echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf;
echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf;

if [[ "${TARGETARCH:-$(dpkg --print-architecture | awk -F'-' '{print $NF}')}" == amd64 ]]; then
    NVARCH=x86_64;
else
    NVARCH=sbsa;
fi

echo "NVARCH=$NVARCH" >> /etc/environment;
echo "CUDA_HOME=$CUDA_HOME" >> /etc/environment;
echo "CUDA_VERSION=$CUDA_VERSION" >> /etc/environment;
echo "CUDA_VERSION_MAJOR=$CUDA_VERSION_MAJOR" >> /etc/environment;
echo "CUDA_VERSION_MINOR=$CUDA_VERSION_MINOR" >> /etc/environment;
echo "CUDA_VERSION_PATCH=$CUDA_VERSION_PATCH" >> /etc/environment;
echo "PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}" >> /etc/environment;
echo "LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" >> /etc/environment;

mkdir -p /etc/profile.d

cat <<EOF > /etc/profile.d/z-cuda.sh
#! /usr/bin/env bash

export NVARCH=$NVARCH;
export CUDA_HOME="/usr/local/cuda";
export CUDA_VERSION="$CUDA_VERSION";
export CUDA_VERSION_MAJOR=$CUDA_VERSION_MAJOR;
export CUDA_VERSION_MINOR=$CUDA_VERSION_MINOR;
export CUDA_VERSION_PATCH=$CUDA_VERSION_PATCH;

if [[ -z "\$PATH" || \$PATH != *"\${CUDA_HOME}/bin"* ]]; then
    export PATH="\${CUDA_HOME}/bin:\${PATH:+\$PATH:}";
fi
if [[ -z "\$PATH" || \$PATH != *"/usr/local/nvidia/bin"* ]]; then
    export PATH="/usr/local/nvidia/bin:\${PATH:+\$PATH:}";
fi
if [[ -z "\$LIBRARY_PATH" || \$LIBRARY_PATH != *"\${CUDA_HOME}/lib64/stubs"* ]]; then
    export LIBRARY_PATH="\${LIBRARY_PATH:+\$LIBRARY_PATH:}\${CUDA_HOME}/lib64/stubs";
fi
EOF

chmod +x /etc/profile.d/z-cuda.sh

cat <<EOF > /etc/bash.bash_env
#! /usr/bin/env bash

. /etc/environment;

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
