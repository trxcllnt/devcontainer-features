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

if dpkg -s sccache > /dev/null 2>&1; then
    echo "Uninstalling existing sccache...";
    apt-get remove -y sccache;
    apt-get autoremove -y;
fi

check_packages wget ca-certificates bash-completion

echo "Installing sccache...";

SCCACHE_VERSION=${SCCACHEVERSION:-latest}

if [ $SCCACHE_VERSION == latest ]; then
    check_packages jq;
    SCCACHE_VERSION=;
    while [[ -z $SCCACHE_VERSION ]]; do
        sleep $(($RANDOM % 60));
        SCCACHE_VERSION="$(wget --no-hsts -q -O- https://api.github.com/repos/mozilla/sccache/releases/latest | jq -r ".tag_name" | tr -d 'v')";
    done
fi

# Install sccache
wget --no-hsts -q -O- "https://github.com/mozilla/sccache/releases/download/v$SCCACHE_VERSION/sccache-v$SCCACHE_VERSION-$(uname -p)-unknown-linux-musl.tar.gz" \
    | tar -C /usr/bin -zf - --wildcards --strip-components=1 -x */sccache \
 && chmod +x /usr/bin/sccache

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/*;
