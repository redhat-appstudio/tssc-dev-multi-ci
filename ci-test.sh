# get local test repos to patch
source setup-local-dev-repos.sh
source init-tas-vars.sh
eval "$(hack/get-trustification-env.sh)"

# sed behaves differently on different platforms
# sed --version is not valid on BSD, while it is valid on the GNU version
SED_CMD() {
    if sed --version > /dev/null 2>&1; then
        # GNU version
        sed -i "$@"
    else
        # BSD version
        sed -i "" "$@"
    fi
}

# setting secrets for the dev repos is slow
# after the first setting, you can skip this step
# warning, if your secrets are stale, do not skip this step
SKIP_SECRETS=${SKIP_SECRETS:-false}
USE_RHTAP_IMAGES=${USE_RHTAP_IMAGES:-false}

if [ "$SKIP_SECRETS" == "true" ]; then
    echo "WARNING SKIP_SECRETS set to true, skipping configuration of secrets"
fi
if [ "$USE_RHTAP_IMAGES" == "true" ]; then
    echo "USE_RHTAP_IMAGES is set to $USE_RHTAP_IMAGES"
    echo "Note - configuration is going to use the runner images and Jenkins from redhat-appstudio"
else
    echo "USE_RHTAP_IMAGES is set to $USE_RHTAP_IMAGES"
    echo "Note - configuration is going to use the runner images#MY_QUAY_USER and Jenkins MY_GITHUB_USER"
fi

if [ "$TEST_REPO_ORG" == "redhat-appstudio" ]; then
    echo "Cannot do CI testing using the redhat-appstudio org"
    echo "You must create forks in your own org and set up MY_TEST_REPO_ORG (github) and MY_TEST_REPO_GITLAB_ORG"
    exit
fi

function updateGitAndQuayRefs() {
    if [ "$USE_RHTAP_IMAGES" == "true" ]; then
        echo "USE_RHTAP_IMAGES is set to $USE_RHTAP_IMAGES"
        echo "No images or Jenkins references patched"
    else
        echo "USE_RHTAP_IMAGES is set to $USE_RHTAP_IMAGES"
        echo "images or Jenkins references patched to quay.io/$MY_QUAY_USER and github.com/$MY_GITHUB_USER"
        if [ -f "$1" ]; then
            SED_CMD "s!registry.access.redhat.com/rhtap-task-runner/rhtap-task-runner-rhel9.*!quay.io/$MY_QUAY_USER/rhtap-task-runner:dev!g" "$1"
            SED_CMD "s!https://github.com/redhat-appstudio!https://github.com/$MY_GITHUB_USER!g" "$1"
            SED_CMD "s!RHTAP_Jenkins@.*'!RHTAP_Jenkins@dev'!g" "$1"
        fi
    fi
}

function updateBuild() {
    REPO=$1
    GITOPS_REPO_UPDATE=$2
    mkdir -p "$REPO/rhtap"
    SETUP_ENV=$REPO/rhtap/env.sh
    cp rhtap/env.template.sh "$SETUP_ENV"
    SED_CMD "s!\${{ values.image }}!$IMAGE_TO_BUILD!g" "$SETUP_ENV"
    SED_CMD "s!\${{ values.dockerfile }}!Dockerfile!g" "$SETUP_ENV"
    SED_CMD "s!\${{ values.buildContext }}!.!g" "$SETUP_ENV"
    SED_CMD "s!\${{ values.repoURL }}!$GITOPS_REPO_UPDATE!g" "$SETUP_ENV"
    # Update REKOR_HOST and TUF_MIRROR values directly
    SED_CMD '/export REKOR_HOST=/d' "$SETUP_ENV"
    SED_CMD '/export TUF_MIRROR=/d' "$SETUP_ENV"
    SED_CMD '/export IGNORE_REKOR=/d' "$SETUP_ENV"

    {
        echo ""
        echo "export REKOR_HOST=$REKOR_HOST"
        echo "export IGNORE_REKOR=$IGNORE_REKOR"
        echo "export TUF_MIRROR=$TUF_MIRROR"
        echo "# Update forced CI test $(date)"
    } >> "$SETUP_ENV"

    if [[ "$TEST_PRIVATE_REGISTRY" == "true" ]]; then
        echo "WARNING Due to private repos, disabling ACS"
        SED_CMD '/export DISABLE_ACS=/d' "$SETUP_ENV"
        echo "export DISABLE_ACS=true" >> "$SETUP_ENV"
    fi

    updateGitAndQuayRefs "$SETUP_ENV"
    cat "$SETUP_ENV"
}

function updateRepos() {
    REPO=$1
    echo
    echo "Updating $REPO"
    pushd "$REPO"
    git add .
    git commit -m "Testing in CI"
    git push
    popd
}

function test_jenkins() {
    echo "Testing Jenkins..."
    echo

    # update the jenkins library in the dev branch
    bash hack/update-jenkins-library

    # source repos are updated with the name of the corresponding GITOPS REPO for update-deployment
    updateBuild "$JENKINS_BUILD" "$TEST_GITOPS_JENKINS_REPO"
    updateBuild "$JENKINS_GITOPS"

    echo "Update Jenkins file in $JENKINS_BUILD and $JENKINS_GITOPS"
    echo "NEW - JENKINS USES A SEPARATE REPO FROM GITHUB ACTIONS"
    cp $GEN_SRC/jenkins/Jenkinsfile "$JENKINS_BUILD"/Jenkinsfile
    cp $GEN_GITOPS/jenkins/Jenkinsfile "$JENKINS_GITOPS"/Jenkinsfile
    updateGitAndQuayRefs "$JENKINS_BUILD"/Jenkinsfile
    updateGitAndQuayRefs "$JENKINS_GITOPS"/Jenkinsfile

    # note, jenkins secrets are global so set once
    if [ "$SKIP_SECRETS" == "false" ]; then
        bash hack/jenkins-set-secrets
    fi
    updateRepos "$JENKINS_BUILD"
    updateRepos "$JENKINS_GITOPS"

    bash hack/jenkins-run-pipeline "$(basename "$TEST_BUILD_JENKINS_REPO")"

    echo
    echo "Jenkins Build and Gitops Repos"
    echo "Build: $TEST_BUILD_JENKINS_REPO"
    echo "Gitops: $TEST_GITOPS_JENKINS_REPO"
}

function test_gh_actions() {
    echo "Testing GitHub Actions..."
    echo

    # source repos are updated with the name of the corresponding GITOPS REPO for update-deployment
    updateBuild "$BUILD" "$TEST_GITOPS_REPO"
    updateBuild "$GITOPS"

    echo "Update .github workflows in $BUILD and $GITOPS"
    cp -r $GEN_SRC/githubactions/.github "$BUILD"
    cp -r $GEN_GITOPS/githubactions/.github "$GITOPS"
    for wf in "$BUILD"/.github/workflows/* "$GITOPS"/.github/workflows/*; do
        updateGitAndQuayRefs "$wf"
    done

    # set secrets and then push to repos to ensure pipeline runs are
    # with correct values
    # github
    if [ "$SKIP_SECRETS" == "false" ]; then
        bash hack/ghub-set-vars "$TEST_BUILD_REPO"
        bash hack/ghub-set-vars "$TEST_GITOPS_REPO"
    fi

    updateRepos "$BUILD"
    updateRepos "$GITOPS"

    echo
    echo "Github Build and Gitops Repos"
    echo "Build: $TEST_BUILD_REPO"
    echo "Gitops: $TEST_GITOPS_REPO"
}

function test_gitlab_ci() {
    echo "Testing GitLab CI..."
    echo

    # source repos are updated with the name of the corresponding GITOPS REPO for update-deployment
    updateBuild "$GITLAB_BUILD" "$TEST_GITOPS_GITLAB_REPO"
    updateBuild "$GITLAB_GITOPS"

    # Gitlab CI
    echo "Update .gitlab-ci.yml file in $GITLAB_BUILD and $GITLAB_GITOPS"
    cp $GEN_SRC/gitlabci/.gitlab-ci.yml "$GITLAB_BUILD"/.gitlab-ci.yml
    cp $GEN_GITOPS/gitlabci/.gitlab-ci.yml "$GITLAB_GITOPS"/.gitlab-ci.yml
    updateGitAndQuayRefs "$GITLAB_BUILD"/.gitlab-ci.yml
    updateGitAndQuayRefs "$GITLAB_GITOPS"/.gitlab-ci.yml

    # gitlab
    if [ "$SKIP_SECRETS" == "false" ]; then
        bash hack/glab-set-vars "$(basename "$TEST_BUILD_GITLAB_REPO")"
        bash hack/glab-set-vars "$(basename "$TEST_GITOPS_GITLAB_REPO")"
    fi
    updateRepos "$GITLAB_BUILD"
    updateRepos "$GITLAB_GITOPS"

    echo ""
    echo "Gitlab Build and Gitops Repos"
    echo "Build: $TEST_BUILD_GITLAB_REPO"
    echo "Gitops: $TEST_GITOPS_GITLAB_REPO"
}

function test_azure_pipelines() {
    updateBuild $AZURE_BUILD $TEST_GITOPS_AZURE_REPO
    updateBuild $AZURE_GITOPS

    echo "Update .azure-pipelines.yml file in $AZURE_BUILD and $AZURE_GITOPS"
    cp $GEN_SRC/azure/azure-pipelines.yml $AZURE_BUILD/azure-pipelines.yml
    cp $GEN_GITOPS/azure/azure-pipelines.yml $AZURE_GITOPS/azure-pipelines.yml
    updateGitAndQuayRefs $AZURE_BUILD/azure-pipelines.yml
    updateGitAndQuayRefs $AZURE_GITOPS/azure-pipelines.yml

    if [ $SKIP_SECRETS == "false" ]; then
        python3 hack/azure_set_vars.py
    fi
    updateRepos $AZURE_BUILD
    updateRepos $AZURE_GITOPS

    echo "Azure Build and Gitops Repos"
    echo "Build: $TEST_BUILD_AZURE_REPO"
    echo "Gitops: $TEST_GITOPS_AZURE_REPO"
}

# create latest images for dev github and gitlab
make build-push-image

# source repos for copying the generated manifests
GEN_SRC=generated/source-repo
GEN_GITOPS=generated/gitops-template

test_gh_actions
test_gitlab_ci
test_jenkins
test_azure_pipelines
