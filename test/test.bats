setup_file() {
    TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    ROOT_DIR="$( realpath "${TEST_DIR}/.." )"
    SRC_DIR="${ROOT_DIR}/rhtap"

    PATH="$SRC_DIR:$PATH"

    IMAGE=tssc-runner-image:bats
    export IMAGE

    echo "Building container image..." >&3
    # This should be instant if image is already built, but it may take several minutes otherwise.
    podman build -t "${IMAGE}" "${ROOT_DIR}"
    echo "Container image built sucessfully!" >&3
}

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    REQUIRED_VARS=(
        "IMAGE_URL"
        "IMAGE"
        "COSIGN_SECRET_PASSWORD"
        "COSIGN_SECRET_KEY"
        "COSIGN_PUBLIC_KEY"
        "DISABLE_ACS"
        "ROX_CENTRAL_ENDPOINT"
        "ROX_API_TOKEN"
        "GITOPS_AUTH_PASSWORD"
        "POLICY_CONFIGURATION"
        "REKOR_HOST"
        "IGNORE_REKOR"
        "INFO"
        "STRICT"
        "EFFECTIVE_TIME"
        "HOMEDIR"
    )
    export REQUIRED_VARS

    REQUIRED_VARS_ARGS=()
    for var in "${REQUIRED_VARS[@]}"; do
        # Use a dummy value for each required environment variable
        var_lower=$(echo "$var" | tr '[:upper:]' '[:lower:]')
        REQUIRED_VARS_ARGS+=("-e" "${var}=${var_lower}")
    done
    export REQUIRED_VARS_ARGS

    # Matches: 2025-08-20T20:05:54Z
    TIME_REGEX='[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}Z'
    export TIME_REGEX
}

@test "init.sh verifies required env vars" {
    local workdir
    workdir="$(mktemp -d)"

    run podman run --rm -it \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_failure

    for var in "${REQUIRED_VARS[@]}"; do
        assert_output --partial "Error: ${var} missing definition"
    done

    local status_result="${workdir}/results/init/STATUS"
    assert_exists "${status_result}"
    assert_equal "$(cat "${status_result}")" 'Failed'

    local build_result="${workdir}/results/init/build"
    assert_not_exists "${build_result}"
}

@test "init.sh finds required env vars" {
    local workdir
    workdir="$(mktemp -d)"

    run podman run "${REQUIRED_VARS_ARGS[@]}" --rm -it \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_success

    for var in "${REQUIRED_VARS[@]}"; do
        assert_output --partial "OK: ${var}"
    done

    local status_result="${workdir}/results/init/STATUS"
    assert_exists "${status_result}"
    assert_equal "$(cat "${status_result}")" 'Succeeded'

    local build_result="${workdir}/results/init/build"
    assert_exists "${build_result}"
}

@test "init.sh sets START_TIME result" {
    local workdir
    workdir="$(mktemp -d)"

    run podman run "${REQUIRED_VARS_ARGS[@]}" --rm -it \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_success

    local start_time_result="${workdir}/results/init/START_TIME"
    assert_exists "${start_time_result}"
    assert_regex "$(cat "${start_time_result}")" "${TIME_REGEX}"
}

@test "init.sh skips build if image exists" {
    local workdir
    workdir="$(mktemp -d)"

    run podman run "${REQUIRED_VARS_ARGS[@]}" --rm -it \
        -e IMAGE_URL=quay.io/fedora/fedora:43-x86_64 \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_success

    local status_result="${workdir}/results/init/STATUS"
    assert_exists "${status_result}"
    assert_equal "$(cat "${status_result}")" 'Succeeded'

    local build_result="${workdir}/results/init/build"
    assert_equal "$(cat "${build_result}")" 'false'
}

@test "init.sh forces build if REBUILD is set to true" {
    local workdir
    workdir="$(mktemp -d)"

    run podman run "${REQUIRED_VARS_ARGS[@]}" --rm -it \
        -e REBUILD=true \
        -e IMAGE_URL=quay.io/fedora/fedora:43-x86_64 \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_success

    local status_result="${workdir}/results/init/STATUS"
    assert_exists "${status_result}"
    assert_equal "$(cat "${status_result}")" 'Succeeded'

    local build_result="${workdir}/results/init/build"
    assert_equal "$(cat "${build_result}")" 'true'
}

@test "init.sh forces build if SKIP_CHECKS is set to true" {
    local workdir
    workdir="$(mktemp -d)"

    run podman run "${REQUIRED_VARS_ARGS[@]}" --rm -it \
        -e SKIP_CHECKS=true \
        -e IMAGE_URL=quay.io/fedora/fedora:43-x86_64 \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_success

    local status_result="${workdir}/results/init/STATUS"
    assert_exists "${status_result}"
    assert_equal "$(cat "${status_result}")" 'Succeeded'

    local build_result="${workdir}/results/init/build"
    assert_equal "$(cat "${build_result}")" 'true'
}

@test "init.sh disables ACS env vars" {
    local workdir
    workdir="$(mktemp -d)"

    local vars_args=()
    for var_arg in "${REQUIRED_VARS_ARGS[@]}"; do
        [[ "$var_arg" == *"ROX_CENTRAL_ENDPOINT"* ]] && continue
        [[ "$var_arg" == *"ROX_API_TOKEN"* ]] && continue
        vars_args+=("${var_arg}")
    done

    run podman run "${vars_args[@]}" --rm -it \
        -e DISABLE_ACS=true \
        --volume "${workdir}:/work/src:Z" --workdir /work/src \
        "${IMAGE}" -- /work/rhtap/init.sh
    assert_success

    local status_result="${workdir}/results/init/STATUS"
    assert_exists "${status_result}"
    assert_equal "$(cat "${status_result}")" 'Succeeded'

    local build_result="${workdir}/results/init/build"
    assert_equal "$(cat "${build_result}")" 'true'
}
