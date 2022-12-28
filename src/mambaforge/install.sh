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

check_packages git wget bzip2 ca-certificates bash-completion

echo "Downloading Mambaforge...";

MAMBAFORGE_VERSION=${MAMBAFORGEVERSION:-latest}

if [ $MAMBAFORGE_VERSION == latest ]; then
    check_packages jq;
    MAMBAFORGE_VERSION=;
    while [[ -z $MAMBAFORGE_VERSION ]]; do
        sleep $(($RANDOM % 60));
        MAMBAFORGE_VERSION="$(wget --no-hsts -q -O- https://api.github.com/repos/conda-forge/miniforge/releases/latest | jq -r ".tag_name" | tr -d 'v')";
    done
fi

wget --no-hsts -q -O /tmp/miniforge.sh \
    https://github.com/conda-forge/miniforge/releases/download/${MAMBAFORGE_VERSION}/Mambaforge-${MAMBAFORGE_VERSION}-Linux-$(uname -p).sh

echo "Installing Mambaforge...";

# Install miniconda
/bin/bash /tmp/miniforge.sh -b -p ${CONDADIR}

export PATH="${CONDADIR}/bin:${PATH:+$PATH:}";

conda clean --tarballs --index-cache --packages --yes;
find ${CONDADIR} -follow -type f -name '*.a' -delete;
find ${CONDADIR} -follow -type f -name '*.pyc' -delete;
conda clean --force-pkgs-dirs --all --yes;

# Insert the conda env name into codespaces' modified PS1

for rc_file in /home/*/.bashrc; do
    if [[ -f "$rc_file" ]]; then
        sed -i -re 's/PS1="(\$\{userpart\} )/PS1="${CONDA_PROMPT_MODIFIER:-}\1/g' "$rc_file";
    fi
done

if [[ -f "${_REMOTE_USER_HOME}/.bashrc" ]]; then
    sed -i -re 's/PS1="(\$\{userpart\} )/PS1="${CONDA_PROMPT_MODIFIER:-}\1/g' ${_REMOTE_USER_HOME}/.bashrc;
fi

if [[ -f "${_CONTAINER_USER_HOME}/.bashrc" ]]; then
    sed -i -re 's/PS1="(\$\{userpart\} )/PS1="${CONDA_PROMPT_MODIFIER:-}\1/g' ${_CONTAINER_USER_HOME}/.bashrc;
fi

mkdir -p /etc/profile.d

cat <<EOF > /etc/profile.d/z-conda.sh
export MAMBA_NO_BANNER=1;
if [[ -z "\$PATH" || \$PATH != *"${CONDADIR}/bin"* ]]; then
    export PATH="${CONDADIR}/bin:\${PATH:+\$PATH:}";
fi
. ${CONDADIR}/etc/profile.d/conda.sh && conda activate base
EOF

chmod +x /etc/profile.d/z-conda.sh

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
       /var/lib/apt/lists/* \
       /tmp/miniforge.sh;
