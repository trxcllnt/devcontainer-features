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

mkdir -p /etc/profile.d;

cat <<EOF > ${CONDADIR}/bashrc-snippet.sh
export MAMBA_NO_BANNER=1;
if [[ -z "\$PATH" || \$PATH != *"${CONDADIR}/bin"* ]]; then
    export PATH="${CONDADIR}/bin:\${PATH:+\$PATH:}";
fi
if [[ "\$(conda info -e | grep -q "\${CONDA_DEFAULT_ENV:-base}"; echo \$?)" == 0 ]]; then
    CONDA_DEFAULT_ENV="\${CONDA_DEFAULT_ENV:-base}";
fi
. /opt/conda/etc/profile.d/conda.sh;
conda activate "\${CONDA_DEFAULT_ENV:-base}";
EOF

cat <<EOF > /etc/profile.d/z-conda.sh
export MAMBA_NO_BANNER=1;

if [[ -z "\$PATH" || \$PATH != *"${CONDADIR}/bin"* ]]; then
    export PATH="${CONDADIR}/bin:\${PATH:+\$PATH:}";
fi

if [[ -f "\$HOME/.bashrc" ]]; then
    # Add "conda activate base" to ~/.bashrc
    if [[ "\$(grep -q ". ${CONDADIR}/etc/profile.d/conda.sh" "\$HOME/.bashrc"; echo \$?)" != 0 ]]; then
        if [[ "\$(grep -q "# Codespaces bash prompt theme" "\$HOME/.bashrc"; echo \$?)" == 0 ]]; then
            # Activate conda before the codespaces bash prompt sets PS1
            conda_activate_snippet="\$(printf %q "\$(cat "${CONDADIR}/bashrc-snippet.sh")" | cut -b1 --complement | cut -d\' -f2)";
            sed -i "/^# Codespaces bash prompt theme\\\$/i \${conda_activate_snippet}\n" "\$HOME/.bashrc";
            # Insert the conda env name into codespaces' modified PS1
            sed -i -re 's@PS1="(\\\$\{userpart\} )@PS1="\${CONDA_PROMPT_MODIFIER:-}\1@g' "\$HOME/.bashrc";
        else
            cat "${CONDADIR}/bashrc-snippet.sh" >>  "\$HOME/.bashrc";
        fi
    fi
fi
EOF

chmod +x /etc/profile.d/z-conda.sh;

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

chmod +x /etc/bash.bash_env;

rm -rf /var/tmp/* \
       /var/cache/apt/* \
       /var/lib/apt/lists/* \
       /tmp/miniforge.sh;
