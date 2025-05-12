#!/bin/bash
set -o errexit -o nounset -o pipefail

# Usage:
# - Login to a cluster where RHTAP is deployed (you need admin permissions)
# - Run this script
# - Set the generated env vars before running the promotion pipeline
#   - e.g. with `eval "$(hack/get-trustification-env.sh)"`

TPA_NAMESPACE=${TPA_NAMESPACE:-'tssc-tpa'}
KEYCLOAK_NAMESPACE=${KEYCLOAK_NAMESPACE:-'tssc-keycloak'}

declare -A trustification_env

trustification_env=(
    [BOMBASTIC_API_URL]="https://$(oc -n "$TPA_NAMESPACE" get route --selector app.kubernetes.io/name=bombastic-api -o jsonpath='{.items[].spec.host}')"
    [OIDC_ISSUER_URL]="https://$(oc -n "$KEYCLOAK_NAMESPACE" get route --selector app=keycloak -o jsonpath='{.items[].spec.host}')/realms/chicken"
    [OIDC_CLIENT_ID]=walker
    [OIDC_CLIENT_SECRET]=$(oc -n tssc-tpa get secret tpa-realm-chicken-clients -o go-template='{{.data.walker | base64decode}}')
    [SUPPORTED_CYCLONEDX_VERSION]=1.4
)

for k in "${!trustification_env[@]}"; do
    v=${trustification_env[$k]}
    printf "export TRUSTIFICATION_%s=%q\n" "$k" "$v"
done | sort
