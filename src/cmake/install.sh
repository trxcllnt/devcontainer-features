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

if dpkg -s cmake > /dev/null 2>&1; then
    echo "Uninstalling existing CMake...";
    apt-get remove -y cmake;
    apt-get autoremove -y;
fi

check_packages wget ca-certificates bash-completion pkg-config

echo "Downloading CMake...";

CMAKE_VERSION=${CMAKEVERSION:-latest}

if [ $CMAKE_VERSION == latest ]; then
    check_packages jq;
    CMAKE_VERSION=;
    while [[ -z $CMAKE_VERSION ]]; do
        sleep $(($RANDOM % 60));
        CMAKE_VERSION="$(wget --no-hsts -q -O- https://api.github.com/repos/Kitware/CMake/releases/latest | jq -r ".tag_name" | tr -d 'v')";
    done
fi

wget --no-hsts -q -O /tmp/cmake_${CMAKE_VERSION}.sh \
    https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -p).sh

echo "Installing CMake...";

# Install CMake
bash /tmp/cmake_${CMAKE_VERSION}.sh --skip-license --exclude-subdir --prefix=/usr

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/* \
       /tmp/cmake_${CMAKE_VERSION}.sh;
