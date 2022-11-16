#! /usr/bin/env bash
set -e

echo "Installing LLVM prerequisites...";

apt update;

DEBIAN_FRONTEND=noninteractive         \
apt install -y --no-install-recommends \
    gpg                                \
    wget                               \
    apt-utils                          \
    lsb-release                        \
    ca-certificates                    \
    apt-transport-https                \
    software-properties-common         \
    ;

echo "Downloading LLVM gpg key...";

tmpdir="$(mktemp -d)";
wget -O $tmpdir/llvm-snapshot.asc https://apt.llvm.org/llvm-snapshot.gpg.key;

find "$tmpdir" -type f -name '*.asc' -exec bash -c "gpg --dearmor -o \
  /etc/apt/trusted.gpg.d/$(echo "{}" | sed s@$tmpdir/@@ | sed s@.asc@.gpg@) \
  {}" \;

chmod 0644 /etc/apt/trusted.gpg.d/*.gpg || true;

echo "Installing LLVM compilers and tools${LLVMVERSION:+" (version=${LLVMVERSION})"}";

llvm_ver=${LLVMVERSION:-};
if [[ $llvm_ver == dev ]]; then
    llvm_ver="";
fi

# Install llvm apt repository
apt-add-repository -y "\
deb [arch=$(dpkg-architecture -q DEB_BUILD_ARCH)] \
http://apt.llvm.org/$(lsb_release -cs)/ \
llvm-toolchain-$(lsb_release -cs)${llvm_ver:+"-$llvm_ver"} main";

llvm_ver="$(\
    apt policy llvm 2>/dev/null \
  | grep -E 'Candidate: 1:(.*).*$' - \
  | cut -d':' -f3 \
  | cut -d'.' -f1)";

DEBIAN_FRONTEND=noninteractive                                      \
apt install -y --no-install-recommends                              \
    `# LLVM and Clang`                                              \
    {clang-tools,python3-clang}-${llvm_ver}                         \
    {libc++,libc++abi,libclang,liblldb,libomp,llvm}-${llvm_ver}-dev \
    clang-format clang-tidy clang clangd lld lldb llvm-runtime llvm \
    ;

# Remove existing clang/llvm alternatives
(update-alternatives --remove-all clang        >/dev/null 2>&1 || true);
(update-alternatives --remove-all clangd       >/dev/null 2>&1 || true);
(update-alternatives --remove-all clang++      >/dev/null 2>&1 || true);
(update-alternatives --remove-all clang-format >/dev/null 2>&1 || true);
(update-alternatives --remove-all clang-tidy   >/dev/null 2>&1 || true);
(update-alternatives --remove-all lldb         >/dev/null 2>&1 || true);
(update-alternatives --remove-all llvm-config  >/dev/null 2>&1 || true);
(update-alternatives --remove-all llvm-cov     >/dev/null 2>&1 || true);

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

export CC="$(which clang)";
export CXX="$(which clang++)";

# # Remove existing cc and c++ alternatives
(update-alternatives --remove-all cc  >/dev/null 2>&1 || true);
(update-alternatives --remove-all c++ >/dev/null 2>&1 || true);

# # Install alternatives for cc/c++
# update-alternatives \
#     --install /usr/bin/cc  cc  $(which $CC)  30 \
#     --slave   /usr/bin/c++ c++ $(which $CXX)    \
#     ;

# # Set $CC as the default cc
# update-alternatives --set cc $(which $CC)

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/*;
