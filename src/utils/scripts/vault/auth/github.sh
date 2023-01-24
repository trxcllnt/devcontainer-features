#! /usr/bin/env bash

set -euo pipefail;

vault_token=null;

VAULT_HOST="$1";
user_orgs="${@:2}";
gh_token="$(gh auth token)";

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

echo "vault_token='$vault_token'";

unset vault_token;
