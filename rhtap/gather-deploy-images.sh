#!/bin/bash
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
# gather-deploy-images
source $SCRIPTDIR/common.sh

DEFAULT_INIT_IMAGES=(
    'quay.io/redhat-appstudio/dance-bootstrap-app:latest'
    'registry.redhat.io/ubi9/httpd-24:latest'
)

function get-images-per-env() {
    echo "Running $TASK_NAME:get-images-per-env"
    #!/bin/bash
    set -euo pipefail

    ENVIRONMENTS=("$@")
    if [[ "${#ENVIRONMENTS[@]}" -eq 0 ]]; then
        ENVIRONMENTS=(development stage prod)
    fi

    IMAGE_PATH='.spec.template.spec.containers[0].image'
    IMAGES_FILE=$HOMEDIR/all-images.txt
    component_name=$(yq .metadata.name application.yaml)

    for env in "${ENVIRONMENTS[@]}"; do
        yaml_path=components/${component_name}/overlays/${env}/deployment-patch.yaml
        image=$(yq "$IMAGE_PATH" "$yaml_path")

        for default_image in "${DEFAULT_INIT_IMAGES[@]}"; do
            if [[ "$image" == "$default_image" ]]; then
                # Don't check the default placeholder images
                continue 2 # Go to the next iteration of outer loop, different environment.
            fi
        done

        if [ -n "$TARGET_BRANCH" ]; then
            prev_image=$(git show "origin/$TARGET_BRANCH:$yaml_path" | yq "$IMAGE_PATH")
            if [ "$prev_image" = "$image" ]; then
                # don't check images that didn't change between the current revision and the target branch
                continue
            fi
        fi

        printf "%s\n" "$image"
    done | sort -u > "$IMAGES_FILE"

    # For development purposes, allow injecting your own list of images
    # (Let's remove this when copying the changes to redhat-appstudio/tssc-sample-jenkins)
    if [ -n "${MY_IMAGES_TO_VERIFY:-}" ]; then
        for image in ${MY_IMAGES_TO_VERIFY}; do
            printf "%s\n" "$image"
        done > "$IMAGES_FILE"
    fi

    if [ ! -s "$IMAGES_FILE" ]; then
        echo "No images to verify"
        # create or truncate the IMAGES_TO_VERIFY file
        true > $RESULTS/IMAGES_TO_VERIFY
        exit 0
    fi

    # TODO: each component needs a {"source": {"git": {"url": "...", "revision": "..."}}}
    #       will that be too large for Tekton results?

    jq --compact-output --raw-input --slurp '
	  # split input file
	  split("\n") |
	  # drop empty lines
	  map(select(length > 0)) |
	  # convert into EC-compatible format
	  {
	    "components": map({"containerImage": .})
	  }
	' < "$IMAGES_FILE" | tee $RESULTS/IMAGES_TO_VERIFY

    cat $RESULTS/IMAGES_TO_VERIFY | jq

}

# Task Steps
get-images-per-env "$@"
