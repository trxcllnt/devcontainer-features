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

if [[ ! -L /usr/local/cuda ]]; then
    # Create /usr/local/cuda symlink
    ln -s "/usr/local/cuda-${CUDAVERSION}" "/usr/local/cuda";
fi

for x in  {/etc/skel,${_CONTAINER_USER_HOME}}/.bashrc; do
    cat <<EOF >> $x
export CUDA_HOME="/usr/local/cuda";
export PATH="/usr/local/nvidia/bin:\$CUDA_HOME/bin:\${PATH:+\$PATH:}";
export LIBRARY_PATH="\${LIBRARY_PATH:+\$LIBRARY_PATH:}\$CUDA_HOME/lib64/stubs";
EOF
done

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
