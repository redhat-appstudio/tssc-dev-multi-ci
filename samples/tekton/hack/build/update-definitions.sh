#!/bin/bash

# This script imports tasks and pipeline defintions from build-definitions repository
# and applies them into current namespace.
# Requires BUILD_DEFINITIONS environment variable to be set and point to local build-definitions repository.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$SCRIPT_DIR/../..

"${ROOT_DIR}"/hack/import-build-definitions

oc apply -f "${ROOT_DIR}"/pac/tasks
oc apply -f "${ROOT_DIR}"/pac/pipelines
