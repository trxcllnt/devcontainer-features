#! /usr/bin/env bash

set -euo pipefail;

git_protocol=
if [[ "${CODESPACES:-false}" == true ]]; then
    git_protocol="--git-protocol https";
fi

select_required_scopes() {
    local need="";
    local have="$(GITHUB_TOKEN=              \
        gh api -i -X GET --silent rate_limit \
        2>/dev/null                          \
      | grep -i 'x-oauth-scopes:'            \
    )";

    for scope in "$@"; do
        if [[ ! $have =~ $scope ]]; then
            need="${need:+$need }$scope";
        fi
    done

    echo -n "$(echo -n "$need" | xargs -r -n1 -d' ' echo -n ' --scopes')";
}

scopes="$(select_required_scopes "read:org" ${@})";

if [[ -n "$scopes" ]]; then
    for VAR in GH_TOKEN GITHUB_TOKEN; do
        if [[ -n "$(eval "echo \${${VAR}:-}")" ]]; then
            for ENVFILE in /etc/profile "$HOME/.bashrc"; do
                if [[ "$(grep -q -E "^${VAR}=$" "$ENVFILE" &>/dev/null; echo $?)" != 0 ]]; then
                    echo "${VAR}=" | sudo tee -a "$ENVFILE" >/dev/null;
                fi
            done
            unset ${VAR};
        fi
    done
    unset VAR;
fi

if [[ $(gh auth status &>/dev/null; echo $?) != 0 ]]; then
    echo "Logging into GitHub...";
    gh auth login --hostname github.com --web ${git_protocol} ${scopes};
elif [[ -n "$scopes" ]]; then
    echo "Logging into GitHub...";
    gh auth refresh --hostname github.com ${scopes};
fi

unset scopes;
unset git_protocol;

gh auth setup-git --hostname github.com;

if [[ -z "${GITHUB_USER:-}" ]]; then
    if [[ -f ~/.config/gh/hosts.yml ]]; then
        GITHUB_USER="$(grep --color=never 'user:' ~/.config/gh/hosts.yml | cut -d ':' -f2 | tr -d '[:space:]' || echo '')";
    fi
fi

if [[ -z "${GITHUB_USER:-}" ]]; then
    GITHUB_USER="$(gh api user --jq '.login')";
fi

if [[ -z "${GITHUB_USER:-}" ]]; then
    exit 1;
fi

export GITHUB_USER;
