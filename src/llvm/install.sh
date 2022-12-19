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

check_packages                  \
    gpg                         \
    wget                        \
    apt-utils                   \
    lsb-release                 \
    bash-completion             \
    ca-certificates             \
    apt-transport-https         \
    software-properties-common  \
    ;

echo "Downloading LLVM gpg key...";

tmpdir="$(mktemp -d)";
wget -O $tmpdir/llvm-snapshot.asc https://apt.llvm.org/llvm-snapshot.gpg.key;

find "$tmpdir" -type f -name '*.asc' -exec bash -c "gpg --dearmor -o \
  /etc/apt/trusted.gpg.d/\$(echo '{}' | sed s@$tmpdir/@@ | sed s@.asc@.gpg@) \
  {}" \;

chmod 0644 /etc/apt/trusted.gpg.d/*.gpg || true;

echo "Installing LLVM compilers and tools${LLVMVERSION:+" (version=${LLVMVERSION})"}";

llvm_ver=${LLVMVERSION:-};
if [[ $llvm_ver == dev ]]; then
    llvm_ver="";
fi

# Install llvm apt repository
apt-add-repository -n -y "\
deb http://apt.llvm.org/$(lsb_release -cs)/ \
llvm-toolchain-$(lsb_release -cs)${llvm_ver:+"-$llvm_ver"} main";

apt-get update -y || TRY_DEV_REPO=1;

if [[ "${TRY_DEV_REPO:-0}" == 1 ]]; then
    rm /etc/apt/sources.list.d/*llvm*.list;

    apt-add-repository -y "\
deb http://apt.llvm.org/$(lsb_release -cs)/ \
llvm-toolchain-$(lsb_release -cs) main";

    llvm_ver="";
fi

if [[ -z "$llvm_ver" ]]; then
    llvm_ver="$(\
        apt-cache policy llvm 2>/dev/null \
      | grep -E 'Candidate: 1:(.*).*$' - \
      | cut -d':' -f3 \
      | cut -d'.' -f1)";
fi

DEBIAN_FRONTEND=noninteractive                                       \
apt-get install -y --no-install-recommends                           \
    `# -o Dpkg::Options::="--force-overwrite"`                       \
    `# LLVM and Clang`                                               \
    llvm-${llvm_ver}-runtime                                         \
    {clang-tools,python3-clang,python3-lldb}-${llvm_ver}             \
    {libc++,libc++abi,libclang,liblldb,libomp,llvm}-${llvm_ver}-dev  \
    {clang-format,clang-tidy,clang,clangd,lld,lldb,llvm}-${llvm_ver} \
    ;

# Remove existing clang/llvm/cc/c++ alternatives
(update-alternatives --remove-all clang        >/dev/null 2>&1 || true);
(update-alternatives --remove-all clangd       >/dev/null 2>&1 || true);
(update-alternatives --remove-all clang++      >/dev/null 2>&1 || true);
(update-alternatives --remove-all clang-format >/dev/null 2>&1 || true);
(update-alternatives --remove-all clang-tidy   >/dev/null 2>&1 || true);
(update-alternatives --remove-all lldb         >/dev/null 2>&1 || true);
(update-alternatives --remove-all llvm-config  >/dev/null 2>&1 || true);
(update-alternatives --remove-all llvm-cov     >/dev/null 2>&1 || true);
(update-alternatives --remove-all cc           >/dev/null 2>&1 || true);
(update-alternatives --remove-all c++          >/dev/null 2>&1 || true);

# Install clang/llvm alternatives
update-alternatives \
    --install /usr/bin/clang        clang        $(which clang-${llvm_ver}) 30     \
    --slave   /usr/bin/clangd       clangd       $(which clangd-${llvm_ver})       \
    --slave   /usr/bin/clang++      clang++      $(which clang++-${llvm_ver})      \
    --slave   /usr/bin/clang-format clang-format $(which clang-format-${llvm_ver}) \
    --slave   /usr/bin/clang-tidy   clang-tidy   $(which clang-tidy-${llvm_ver})   \
    --slave   /usr/bin/lldb         lldb         $(which lldb-${llvm_ver})         \
    --slave   /usr/bin/llvm-config  llvm-config  $(which llvm-config-${llvm_ver})  \
    --slave   /usr/bin/llvm-cov     llvm-cov     $(which llvm-cov-${llvm_ver})     \
    ;

# Set default clang/llvm alternatives
update-alternatives --set clang $(which clang-${llvm_ver});

mkdir -p /etc/profile.d

cat <<EOF > /etc/profile.d/z-llvm.sh
export LLVM_VERSION="${llvm_ver}";
EOF

chmod +x /etc/profile.d/z-llvm.sh

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
