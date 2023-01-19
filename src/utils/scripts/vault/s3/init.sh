#! /usr/bin/env bash

set -euo pipefail;

if [[ -z "${VAULT_HOST:-}" ]]; then
    exit 0;
fi

# Login to vault

vault_token=null;

echo ""
echo "Attempting to use your GitHub account to authenticate";
echo "with vault at '$VAULT_HOST'.";
echo ""

# Initialize the GitHub CLI with the appropriate user scopes
. /opt/devcontainer/bin/github/cli/init.sh;

# Attempt to authenticate with GitHub
eval "$(/opt/devcontainer/bin/vault/auth/github.sh "$VAULT_HOST")";

if [[ "${vault_token:-null}" == null ]]; then
    echo "Your GitHub user was not recognized by vault. Exiting." >&2;
    exit 1;
fi

echo "Successfully authenticated with vault!";

# Generate temporary AWS creds
ttl="ttl=43200s";
aws_creds="$(                               \
    curl -s                                 \
        -X POST                             \
        -H "X-Vault-Token: $vault_token"    \
        -H "Content-Type: application/json" \
        "$VAULT_HOST/v1/aws/sts/devs?$ttl"  \
  | jq -r '.data'                           \
)";

unset ttl;
unset vault_token;

aws_role_arn="$(echo "$aws_creds" | jq -r '.arn')";
aws_access_key_id="$(echo "$aws_creds" | jq -r '.access_key')";
aws_session_token="$(echo "$aws_creds" | jq -r '.security_token')";
aws_secret_access_key="$(echo "$aws_creds" | jq -r '.secret_key')";

unset aws_creds;

if [[ "${aws_role_arn:-null}" == null ]]; then
    echo "Failed to generate temporary AWS S3 credentials. Exiting." >&2;
    exit 1;
fi;
if [[ "${aws_access_key_id:-null}" == null ]]; then
    echo "Failed to generate temporary AWS S3 credentials. Exiting." >&2;
    exit 1;
fi;
if [[ "${aws_session_token:-null}" == null ]]; then
    echo "Failed to generate temporary AWS S3 credentials. Exiting." >&2;
    exit 1;
fi;
if [[ "${aws_secret_access_key:-null}" == null ]]; then
    echo "Failed to generate temporary AWS S3 credentials. Exiting." >&2;
    exit 1;
fi;

# Generate AWS config files
mkdir -p ~/.aws;
cat <<EOF > ~/.aws/config
[default]
region=us-east-2
bucket=rapids-sccache-devs
role_arn=$aws_role_arn
EOF
cat <<EOF > ~/.aws/credentials
[default]
aws_access_key_id=$aws_access_key_id
aws_secret_access_key=$aws_secret_access_key
aws_session_token=$aws_session_token
EOF

unset aws_role_arn;
unset aws_access_key_id;
unset aws_session_token;
unset aws_secret_access_key;

chmod 0600 ~/.aws/{config,credentials};

if [[ "$(grep -q -E "^SCCACHE_S3_USE_SSL=true$" ~/.bashrc &>/dev/null; echo $?)" != 0 ]]; then
    echo "export SCCACHE_S3_USE_SSL=true" >> ~/.bashrc;
fi
if [[ "$(grep -q -E "^SCCACHE_REGION=us-east-2$" ~/.bashrc &>/dev/null; echo $?)" != 0 ]]; then
    echo "export SCCACHE_REGION=us-east-2" >> ~/.bashrc;
fi
if [[ "$(grep -q -E "^SCCACHE_BUCKET=rapids-sccache-devs$" ~/.bashrc &>/dev/null; echo $?)" != 0 ]]; then
    echo "export SCCACHE_BUCKET=rapids-sccache-devs" >> ~/.bashrc;
fi

echo "Successfully generated temporary AWS S3 credentials!";
