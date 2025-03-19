echo "Configure the repos for Innerloop dev"

TEST_REPO_ORG="${MY_TEST_REPO_ORG:-redhat-appstudio}"
TEST_REPO_GITLAB_ORG="${MY_TEST_REPO_GITLAB_ORG:-redhat-appstudio}"

if [ $TEST_REPO_ORG == "redhat-appstudio" ]; then
    echo "Build can use redhat-appstudio directly, gitops needs a forked repo."
    echo "Set up a github and gitlab fork in github and gitlab "
    echo "Pass org names in MY_TEST_REPO_ORG and MY_TEST_REPO_GITLAB_ORG"
fi
if [ $TEST_REPO_GITLAB_ORG == "redhat-appstudio" ]; then
    echo "WARNING: Gitops may not use redhat-appstudio, gitops needs a forked repo."
    echo "Set up a github and gitlab fork in github and gitlab "
    echo "Pass org names in MY_TEST_REPO_ORG and MY_TEST_REPO_GITLAB_ORG"
fi

UPSTREAM_BUILD_REPO=https://github.com/redhat-appstudio/devfile-sample-nodejs-dance
UPSTREAM_GITOPS_REPO=https://github.com/redhat-appstudio/tssc-dev-gitops

# this will be copied into a temp directory
# pipelines will be pushed into it for local test
# build and gitops on gitlab
TEST_BUILD_REPO=https://github.com/$TEST_REPO_ORG/devfile-sample-nodejs-dance

# These repos are all optional, if they don't exist, the build can continue
TEST_GITOPS_REPO=https://github.com/$TEST_REPO_ORG/tssc-dev-gitops

TEST_BUILD_GITLAB_REPO=https://gitlab.com/$TEST_REPO_GITLAB_ORG/devfile-sample-nodejs-dance
TEST_GITOPS_GITLAB_REPO=https://gitlab.com/$TEST_REPO_GITLAB_ORG/tssc-dev-gitops

TEST_BUILD_JENKINS_REPO=https://github.com/$TEST_REPO_ORG/tssc-dev-source-jenkins
TEST_GITOPS_JENKINS_REPO=https://github.com/$TEST_REPO_ORG/tssc-dev-gitops-jenkins

TEST_BUILD_AZURE_REPO=https://github.com/$TEST_REPO_ORG/tssc-dev-source-azure
TEST_GITOPS_AZURE_REPO=https://github.com/$TEST_REPO_ORG/tssc-dev-gitops-azure

# If you prefer to use ssh git urls
if [ -n "$USE_SSH_GIT_URLS" ]; then
    TEST_BUILD_REPO_SSH=git@github.com:$TEST_REPO_ORG/devfile-sample-nodejs-dance.git
    TEST_GITOPS_REPO_SSH=git@github.com:$TEST_REPO_ORG/tssc-dev-gitops.git
    TEST_BUILD_GITLAB_REPO_SSH=git@gitlab.com:$TEST_REPO_GITLAB_ORG/devfile-sample-nodejs-dance.git
    TEST_GITOPS_GITLAB_REPO_SSH=git@gitlab.com:$TEST_REPO_GITLAB_ORG/tssc-dev-gitops.git
    TEST_BUILD_JENKINS_REPO_SSH=git@github.com:$TEST_REPO_ORG/tssc-dev-source-jenkins.git
    TEST_GITOPS_JENKINS_REPO_SSH=git@github.com:$TEST_REPO_ORG/tssc-dev-gitops-jenkins.git
    TEST_BUILD_AZURE_REPO_SSH=git@github.com:$TEST_REPO_ORG/tssc-dev-source-azure.git
    TEST_GITOPS_AZURE_REPO_SSH=git@github.com:$TEST_REPO_ORG/tssc-dev-gitops-azure.git
fi

function cloneRepo() {
    UPSTREAM_REPO=$1
    REPO=$2
    REPO_HTTPS=$3
    # $REPO and $REPO_HTTPS are the same unless $USE_SSH_GIT_URLS is set
    DEST=$4

    # Assume $REPO_HTTPS is like "https://github.com/org/repo"
    # and use cut to pull out the "org/repo" part
    ORG_AND_REPO=$(echo "$REPO_HTTPS" | cut -d/ -f4,5)

    # Clone from the "uptream" repo
    echo "Clone from $UPSTREAM_REPO into $DEST"
    git clone --quiet $UPSTREAM_REPO $DEST > /dev/null

    REPO_EXISTS=$(curl -s -o /dev/null -I -w "%{http_code}" $REPO_HTTPS)
    # 200 == exists
    # 404 == does not exist
    if [ $REPO_EXISTS == 200 ]; then
        # Test "fork" repo exists
        true
    else
        # Test "fork" repo does not exist
        if [[ $REPO_HTTPS =~ github.com ]]; then
            # Create it
            echo Creating repo at $REPO_HTTPS
            gh repo create "$ORG_AND_REPO" --public
        else
            # Ask user to create it
            # (Todo: Create it using GitLab's REST API)
            echo Please manually create a repo at $REPO_HTTPS
            echo "(Configure to allow force push to main)"
            exit 1
        fi
    fi

    # Remove the original "upstream" remote and add a new one
    pushd $DEST
    echo "Updating origin to $REPO"
    git remote set-url origin "$REPO"

    # Force push so we start from a known state
    echo "Force pushing to main branch"
    git push --quiet -f origin main:main
    popd
}

# clone if repos exist, disable gitops
# Github in build/gitops
# Gitlab in gitlab-build, gitlab-gitops
# Jenkins in jenkins-build, jenkins-gitops
# Azure in azure-build, azure-gitops

TMP_REPOS=tmp
rm -rf $TMP_REPOS/*
BUILD=$TMP_REPOS/build
GITOPS=$TMP_REPOS/gitops
GITLAB_BUILD=$TMP_REPOS/gitlab-build
GITLAB_GITOPS=$TMP_REPOS/gitlab-gitops
JENKINS_BUILD=$TMP_REPOS/jenkins-build
JENKINS_GITOPS=$TMP_REPOS/jenkins-gitops
AZURE_BUILD=$TMP_REPOS/azure-build
AZURE_GITOPS=$TMP_REPOS/azure-gitops

# Change this for public or private image testing
export TEST_PRIVATE_REGISTRY=${TEST_PRIVATE_REGISTRY:-true}
if [[ "$TEST_PRIVATE_REGISTRY" == "true" ]]; then
    echo "Note, private image being built by ci-test, acs disabled"
    IMAGE_TO_BUILD=quay.io/$MY_QUAY_USER/private-image
else
    IMAGE_TO_BUILD=quay.io/$MY_QUAY_USER/bootstrap
fi

cloneRepo $UPSTREAM_BUILD_REPO ${TEST_BUILD_REPO_SSH:-$TEST_BUILD_REPO} $TEST_BUILD_REPO $BUILD
cloneRepo $UPSTREAM_GITOPS_REPO ${TEST_GITOPS_REPO_SSH:-$TEST_GITOPS_REPO} $TEST_GITOPS_REPO $GITOPS
cloneRepo $UPSTREAM_BUILD_REPO ${TEST_BUILD_GITLAB_REPO_SSH:-$TEST_BUILD_GITLAB_REPO} $TEST_BUILD_GITLAB_REPO $GITLAB_BUILD
cloneRepo $UPSTREAM_GITOPS_REPO ${TEST_GITOPS_GITLAB_REPO_SSH:-$TEST_GITOPS_GITLAB_REPO} $TEST_GITOPS_GITLAB_REPO $GITLAB_GITOPS
cloneRepo $UPSTREAM_BUILD_REPO ${TEST_BUILD_JENKINS_REPO_SSH:-$TEST_BUILD_JENKINS_REPO} $TEST_BUILD_JENKINS_REPO $JENKINS_BUILD
cloneRepo $UPSTREAM_GITOPS_REPO ${TEST_GITOPS_JENKINS_REPO_SSH:-$TEST_GITOPS_JENKINS_REPO} $TEST_GITOPS_JENKINS_REPO $JENKINS_GITOPS
cloneRepo $UPSTREAM_BUILD_REPO ${TEST_BUILD_AZURE_REPO_SSH:-$TEST_BUILD_AZURE_REPO} $TEST_BUILD_AZURE_REPO $AZURE_BUILD
cloneRepo $UPSTREAM_GITOPS_REPO ${TEST_GITOPS_AZURE_REPO_SSH:-$TEST_GITOPS_AZURE_REPO} $TEST_GITOPS_AZURE_REPO $AZURE_GITOPS

# Avoid messing with your real $HOME/.gitconfig when running locally
if [ -n "$LOCAL_SHELL_RUN" ]; then
    export GIT_CONFIG_GLOBAL=$(pwd)/$TMP_REPOS/.gitconfig
    echo GIT_CONFIG_GLOBAL=$GIT_CONFIG_GLOBAL
fi

# WARNING - if GITOPS_REPO_URL is set, update deployment will try to update
# the gitops repo. Disable this here if the gitops repo is NOT a fork
if [ $TEST_REPO_ORG == "redhat-appstudio" ]; then
    echo "------------- INFO-------------"
    echo "DISABLING GITOPS REPO UPDATE for the "redhat-appstudio" org"
    echo "This prevents random accidental updates to the shared repo by dev team members with access"
    export DISABLE_GITOPS_UPDATE=true
    echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
    echo
fi
