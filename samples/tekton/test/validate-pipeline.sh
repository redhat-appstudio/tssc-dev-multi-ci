#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$SCRIPT_DIR/..
DEBUG_OUTPUT=${DEBUG_OUTPUT:-'/tmp/log.txt'}
EVENT_TYPE=${EVENT_TYPE:-'push'}
PIPELINE="${PIPELINE:-docker-build-rhtap}"
TASKS=("update-deployment" "acs-deploy-check")

NAMESPACE="test-pipeline$(shuf -i 0-9999999 -n 1)"

echo "Create a new test project"
oc new-project "$NAMESPACE"

# wait_for_pipeline takes resource reference ("pipelineruns/pipelinerun-name") and a namespace as arguments
wait_for_pipeline() {
    local timeout_seconds=$((15 * 60))
    if ! oc wait --for=condition=succeeded "$1" -n "$2" --timeout "${timeout_seconds}s" >"$DEBUG_OUTPUT"; then
        echo "[ERROR] RHTAP Pipeline failed to complete successful" >&2
        oc get "$1" -n "$2" -o yaml >"$DEBUG_OUTPUT"
        exit 1
    fi
}

echo "Preparing rhtap sample pipelines build resources..."
"${ROOT_DIR}"/hack/build/prepare-build-resources.sh || status="$?" || :

echo "Apply the rhtap tasks and pipelines in the test namespace $NAMESPACE..."
oc apply -f "${ROOT_DIR}/pac/tasks"
oc apply -f "${ROOT_DIR}/pac/pipelines/docker-build-rhtap.yaml"

# Run the rhtap sample build pipeline
"${ROOT_DIR}"/hack/build/run-build.sh || status="$?" || :

wait_for_pipeline "pipelineruns/$PIPELINE" "$NAMESPACE"

echo "Verify the deployment taskruns on push or pull_request event type..."
if [[ "${EVENT_TYPE}" == "pull_request" ]]; then
    taskruns=$(oc get pipelineruns/"$PIPELINE" -n "$NAMESPACE" -o jsonpath='{.status.skippedTasks[*].name}')
    for task in "${TASKS[@]}"; do
        if ! grep -q "$task" <<< "$taskruns"; then
            echo "Error: task: $task does not skip on pull_request events"
            exit 1
        fi
    done
else
    for task in "${TASKS[@]}"; do
        if oc get taskruns/"$PIPELINE"-"$task" -n "$NAMESPACE" -o jsonpath='{.status.conditions[*].reason}' != "Succeeded"; then
            echo "Error: task: $task skipped or failed to run on push events"
            exit 1
        fi
    done
fi

exit "${status:-0}"
