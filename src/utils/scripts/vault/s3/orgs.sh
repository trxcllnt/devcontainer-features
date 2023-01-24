#! /usr/bin/env bash

set -euo pipefail;

VAULT_HOST="$1";
allowed_orgs="${VAULT_GITHUB_ORGS:-nvidia nv-legate rapids}";
allowed_orgs="${allowed_orgs// /|}";

user_orgs="$(                                    \
    gh api                                       \
        user/orgs                                \
        --jq '.[].login'                         \
        -H "Accept: application/vnd.github+json" \
  | grep --color=never -E "($allowed_orgs)"      \
)";

echo "user_orgs='$user_orgs'";
echo "allowed_orgs='$allowed_orgs'";

unset user_orgs;
unset allowed_orgs;
