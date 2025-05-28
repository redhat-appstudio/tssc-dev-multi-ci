#!/bin/bash
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# acs-deploy-check
source $SCRIPTDIR/common.sh

function rox-deploy-check() {
    echo "Running $TASK_NAME:rox-deploy-check"
    #!/usr/bin/env bash
    set +x

    if [ "$DISABLE_ACS" == "true" ]; then
        echo "DISABLE_ACS is set. No scans will be produced"
        exit_with_success_result
    fi
    if [ "$DISABLE_GITOPS_UPDATE" == "true" ]; then
        echo "DISABLE_GITOPS_UPDATE is set. No repo update will occur"
        exit_with_success_result
    fi
    if [ -z "$GITOPS_REPO_URL" ]; then
        echo "GITOPS_REPO_URL not set to a value, deployment will not be updated"
        exit_with_success_result
    fi
    if [ -z "$ROX_API_TOKEN" ]; then
        echo "ROX_API_TOKEN is not set, demo will exit with success"
        exit_with_success_result
    fi
    if [ -z "$ROX_CENTRAL_ENDPOINT" ]; then
        echo "ROX_CENTRAL_ENDPOINT is not set, demo will exit with success"
        exit_with_success_result
    fi

    echo "Using rox central endpoint ${ROX_CENTRAL_ENDPOINT}"

    if [[ -n "$GITOPS_AUTH_PASSWORD" ]]; then
        gitops_repo_url=${GITOPS_REPO_URL%'.git'}
        remote_without_protocol=${gitops_repo_url#'https://'}
        password=$GITOPS_AUTH_PASSWORD
        if [[ -n "$GITOPS_AUTH_USERNAME" ]]; then
            username=$GITOPS_AUTH_USERNAME
            hostname=$(echo "${GITOPS_REPO_URL}" | awk -F/ '{print $3}')
            echo "https://${username}:${password}@${hostname}" > "${HOME}/.ci-test-git-credentials"
            git config --global "credential.https://${hostname}.helper" "store --file ${HOME}/.ci-test-git-credentials"
            origin_with_auth=https://${username}:${password}@${remote_without_protocol}.git
        else
            origin_with_auth=https://${password}@${remote_without_protocol}.git
        fi
    else
        echo "WARNING git credentials to clone gitops repository ${GITOPS_REPO_URL} is not configured."
    fi

    # Clone gitops repository
    echo "Using gitops repository: ${GITOPS_REPO_URL}"
    git clone "${GITOPS_REPO_URL}" --single-branch --depth 1 gitops
    cd gitops
    echo "List of files in gitops repository root:"
    ls -al
    echo "List of components in the gitops repository:"
    ls -l components/

    echo "Download roxctl cli"
    if [ "${INSECURE_SKIP_TLS_VERIFY}" = "true" ]; then
        curl_insecure='--insecure'
    fi
    curl $curl_insecure -s -L -H "Authorization: Bearer $ROX_API_TOKEN" \
        "https://${ROX_CENTRAL_ENDPOINT}/api/cli/download/roxctl-linux" \
        --output ./roxctl \
        > /dev/null
    if [ $? -ne 0 ]; then
        echo 'Failed to download roxctl'
        exit_with_fail_result
    fi
    chmod +x ./roxctl > /dev/null

    component_name=$(yq .metadata.name application.yaml)
    echo "Performing scan for ${component_name} component"
    file_to_check="components/${component_name}/base/deployment.yaml"
    if [ -f "$file_to_check" ]; then
        echo "ROXCTL on $file_to_check"
        ./roxctl deployment check \
            $([ "${INSECURE_SKIP_TLS_VERIFY}" = "true" ] && echo -n "--insecure-skip-tls-verify") \
            -e "${ROX_CENTRAL_ENDPOINT}" --file "$file_to_check" --output json \
            > $TEMP_DIR/roxctl_deployment_check_output.json
        cp $TEMP_DIR/roxctl_deployment_check_output.json acs-deploy-check.json
    else
        echo "Failed to find file to check: $file_to_check"
        exit 2
    fi
}

function report() {
    echo "Running $TASK_NAME:report"
    #!/usr/bin/env bash
    echo "ACS_DEPLOY_EYECATCHER_BEGIN"
    cat acs-deploy-check.json
    echo "ACS_DEPLOY_EYECATCHER_END"
}

# Task Steps
rox-deploy-check
report
exit_with_success_result
