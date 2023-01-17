#! /usr/bin/env bash

set -euo pipefail;

# Login to vault

vault_token=null;
VAULT_HOST="${VAULT_HOST:-https://vault.ops.k8s.rapids.ai}"

echo ""
echo "Attempting to authenticate with vault at '$VAULT_HOST'";
echo ""

# Initialize the GitHub CLI with the appropriate user scopes
. /opt/devcontainer/bin/github/cli/init.sh || exit $?;

echo "Attempting to use GitHub credentials to authenticate with vault at '$VAULT_HOST'";

# Attempt to authenticate with the GitHub token first
eval "$(. /opt/devcontainer/bin/vault/auth/github.sh "$VAULT_HOST")";

if [[ "${vault_token:-null}" == null ]]; then

    # Fallback to OIDC manual authentication
    echo "GitHub auth failed, attempting manual OIDC auth" >&2;

    eval "$(. /opt/devcontainer/bin/vault/auth/oidc.sh "$VAULT_HOST")";

    if [[ "${vault_token:-null}" == null ]]; then
        echo "Manual OIDC authentication failed. Exiting." >&2;
        exit 1;
    fi
    echo "Successfully authenticated with vault!";
fi

# Generate temporary AWS creds
aws_creds="$(                               \
    curl -s                                 \
        -X POST                             \
        -H "X-Vault-Token: $vault_token"    \
        -H "Content-Type: application/json" \
        "$VAULT_HOST/v1/aws/sts/devs"       \
  | jq -r '.data'                           \
)";

aws_role_arn="$(echo "$aws_creds" | jq -r '.arn')";
aws_access_key_id="$(echo "$aws_creds" | jq -r '.access_key')";
aws_session_token="$(echo "$aws_creds" | jq -r '.security_token')";
aws_secret_access_key="$(echo "$aws_creds" | jq -r '.secret_key')";

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
