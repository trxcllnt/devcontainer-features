#! /usr/bin/env bash
set -e

# Ensure we're in this feature's directory during build
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# install global/common scripts
. ./common/install.sh;

# Install Devcontainer utility scripts to /opt/devcontainer
mkdir -p /opt/devcontainer;
cp -ar ./scripts /opt/devcontainer/bin;

find /opt/devcontainer \
    \( -type d -exec chmod u+rwx,g+rwx,o+rx {} \; \
    -o -type f -exec chmod u+rwx,g+rwx,o+rx {} \; \);

# Enable GCC colors
for_each_user_bashrc 'sed -i -re "s/^#(export GCC_COLORS)/\1/g" "$0"';
# Unlimited history size
for_each_user_bashrc 'sed -i -re "s/^(HIST(FILE)?SIZE=).*$/\1/g" "$0"';
# Append history lines as soon as they're entered
for_each_user_bashrc 'echo "PROMPT_COMMAND=\"history -a; \$PROMPT_COMMAND\"" >> "$0"';

# Generate bash completions
if dpkg -s bash-completion >/dev/null 2>&1; then
    if type gh >/dev/null 2>&1; then
        gh completion -s bash | tee /etc/bash_completion.d/gh >/dev/null;
    fi
    if type glab >/dev/null 2>&1; then
        glab completion -s bash | tee /etc/bash_completion.d/glab >/dev/null;
    fi
fi

# Clean up
rm -rf "/tmp/*";
rm -rf "/var/tmp/*";
rm -rf "/var/cache/apt/*";
rm -rf "/var/lib/apt/lists/*";
