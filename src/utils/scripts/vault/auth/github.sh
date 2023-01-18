#! /usr/bin/env bash

set -euo pipefail;

vault_token=null;

VAULT_HOST="$1";
gh_token="$(gh auth token)";

allowed_orgs="${VAULT_GITHUB_ORGS:-nvidia nv-legate rapids}";
allowed_orgs="${allowed_orgs// /|}";

user_orgs="$(                                    \
    gh api                                       \
        user/orgs                                \
        --jq '.[].login'                         \
        -H "Accept: application/vnd.github+json" \
  | grep --color=never -E "($allowed_orgs)"      \
)";

for org in ${user_orgs}; do
    vault_token="$(                                   \
        curl -s                                       \
            -X POST                                   \
            -H "Content-Type: application/json"       \
            -d "{\"token\": \"$gh_token\"}"           \
            "$VAULT_HOST/v1/auth/github-${org}/login" \
      | jq -r '.auth.client_token'                    \
    )";
    if [[ "${vault_token:-null}" != null ]]; then
        break;
    fi
done

unset org;
unset gh_token;
unset user_orgs;
unset allowed_orgs;

echo "vault_token='$vault_token'";

unset vault_token;
