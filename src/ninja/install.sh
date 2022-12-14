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

if dpkg -s ninja-build > /dev/null 2>&1; then
    echo "Uninstalling existing ninja...";
    apt-get remove -y ninja-build;
    apt-get autoremove -y;
fi

check_packages wget unzip ca-certificates bash-completion

echo "Installing ninja-build...";

NINJA_VERSION=${NINJAVERSION:-latest}

if [ $NINJA_VERSION == latest ]; then
    check_packages jq;
    NINJA_VERSION=;
    while [[ -z $NINJA_VERSION ]]; do
        sleep $(($RANDOM % 60));
        NINJA_VERSION="$(wget --no-hsts -q -O- https://api.github.com/repos/ninja-build/ninja/releases/latest | jq -r ".tag_name" | tr -d 'v')";
    done
fi

# Install Ninja
wget --no-hsts -q -O /tmp/ninja-linux.zip \
    https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip
unzip -d /usr/bin /tmp/ninja-linux.zip
chmod +x /usr/bin/ninja

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/* \
       /tmp/ninja-linux.zip;
