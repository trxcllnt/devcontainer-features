#! /usr/bin/env bash

##
# Try to reopen this vscode window to the ~/workspace.code-workspace file.
##

set -u;

_file="$HOME/workspace.code-workspace";
_code="$(echo /vscode/vscode-server/bin/linux-*/*/bin/remote-cli/code)";

# Only run if a ~/workspace.code-workspace exists
if [[ ! -f "$_file" ]]; then exit 0; fi;

# Only run if in a vscode remote containers session.
if [[ "${REMOTE_CONTAINERS:-false}" == true ]]; then
    for ((i=1; i<=5; i++)); do
        # If the window was reloaded, multiple vscode-ipc sockets will exist.
        # Try them all until one succeeds.
        _sockets="$(echo /tmp/vscode-ipc-*.sock)";
        for _sock in $_sockets; do
            # This is a no-op if the current window is already showing the workspace.
            VSCODE_IPC_HOOK_CLI="$_sock" "$_code" -r "$_file" 2>/dev/null;
            if [[ $? == 0 ]]; then exit 0; fi
        done
        sleep 1;
    done
fi
