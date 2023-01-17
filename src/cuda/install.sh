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

mkdir -p /etc/profile.d

cat <<EOF > /etc/profile.d/z-cuda.sh
#! /usr/bin/env bash

export CUDA_HOME="/usr/local/cuda";
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
