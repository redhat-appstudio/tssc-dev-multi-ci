#!/bin/bash
set -o errexit -o nounset -o pipefail

kubectl -n rhtap get secret tssc-github-integration -o json | jq --raw-output '
    .data |
    {
        GITHUB__APP__ID: .id,
        GITHUB__APP__CLIENT__ID: .clientId,
        GITHUB__APP__WEBHOOK__SECRET: .webhookSecret,
        GITHUB__APP__CLIENT__SECRET: .clientSecret,
        GITHUB__APP__PRIVATE_KEY: .pem,
    }
    | to_entries[] | "\(.key) \(.value)"
' | while read -r key value; do
    printf "export %s=%q\n" "$key" "$(base64 -d <<< "$value")"
done
