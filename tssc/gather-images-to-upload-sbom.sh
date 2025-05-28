#!/bin/bash
set -o errexit -o nounset -o pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

"$SCRIPTDIR/gather-deploy-images.sh" stage prod
