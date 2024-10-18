# from init
export REBUILD=true
export SKIP_CHECKS=true

CI_TYPE=${CI_TYPE:-jenkins}

# from buildah-rhtap
TAG=$(git rev-parse HEAD)
export IMAGE_URL=quay.io/${MY_QUAY_USER:-jduimovich0}/bootstrap:$CI_TYPE-$TAG
export IMAGE=$IMAGE_URL

export DOCKERFILE=Dockerfile
export CONTEXT=.
export TLSVERIFY=false
export BUILD_ARGS=""
export BUILD_ARGS_FILE=""

# from ACS_*.*
export DISABLE_ACS=false
# Optionally set ROX_CENTRAL_ENDPOINT here instead of configuring a Jenkins secret
# export ROX_CENTRAL_ENDPOINT=central-acs.apps.user.cluster.domain.com:443
export INSECURE_SKIP_TLS_VERIFY=true
export GITOPS_REPO_URL=

export PARAM_IMAGE=$IMAGE
export PARAM_IMAGE_DIGEST=$(cat "$BASE_RESULTS/buildah-rhtap/IMAGE_DIGEST" 2>/dev/null || echo "latest")

# From Summary
export SOURCE_BUILD_RESULT_FILE=

# gather images params

export TARGET_BRANCH=""
# enterprise contract
export POLICY_CONFIGURATION="github.com/enterprise-contract/config//rhtap-jenkins"
#internal, assumes jenkins is local openshift
export REKOR_HOST="${MY_REKOR_HOST:-http://rekor-server.rhtap.svc}"
export IGNORE_REKOR=false
export INFO=true
export STRICT=true
export EFFECTIVE_TIME=now
export HOMEDIR=$(pwd)
export TUF_MIRROR="${MY_TUF_MIRROR:-http://tuf.rhtap.svc}"
