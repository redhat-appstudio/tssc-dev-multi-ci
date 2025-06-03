#!/bin/bash

set -euo pipefail

# These variables are automatically injected by Kubernetes. NOTE: If this image is executed
# via a Tekton Task, the entrypoint is not used so we don't need to take that use case into
# account in this script.
if [[ -n "${KUBERNETES_SERVICE_HOST:-}${KUBERNETES_SERVICE_PORT:-}" ]]; then
    echo "Running in Kubernetes Deployment - starting web server..."
    exec splashy
else
    echo "Not running in Kubernetes Deployment - executing command..."
    exec "$@"
fi
