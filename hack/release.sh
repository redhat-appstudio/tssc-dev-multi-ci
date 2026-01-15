#!/bin/bash

set -o errexit -o nounset -o pipefail

# --- 1. PRE-FLIGHT CHECKS ---

# Check if GitHub CLI is authenticated
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ Error: GitHub CLI is not authenticated."
    echo "Please run 'gh auth login' or set the GH_TOKEN variable before running this script."
    exit 1
fi

# Verify NEW_VERSION is set
if [ -z "${NEW_VERSION:-}" ]; then
    echo "❌ Error: NEW_VERSION environment variable is not set."
    exit 1
fi

NEW_BRANCH="release-v${NEW_VERSION}.x"
SCRIPT_NAME=$(basename "$0")

echo "🚀 Preparing release for version: ${NEW_VERSION}"
echo "📂 Target branch will be: ${NEW_BRANCH}"
read -p "Is this correct? (y/n): " confirm
[[ $confirm != [yY] ]] && echo "Aborting." && exit 1

# Check if branch exists on origin
if git ls-remote --heads origin "$NEW_BRANCH" | grep -q "$NEW_BRANCH"; then
    echo "❌ Error: Branch '$NEW_BRANCH' already exists on origin. Delete it or change version."
    exit 1
fi

# Check if branch exists on upstream
if git ls-remote --heads upstream "$NEW_BRANCH" | grep -q "$NEW_BRANCH"; then
    echo "❌ Error: Branch '$NEW_BRANCH' already exists on upstream. Delete it or change version."
    exit 1
fi

# --- 2. REFRESH MAIN ---

echo "🔄 Refreshing main..."
git checkout main
git fetch upstream
git merge upstream/main
git push origin main

# --- 3. CREATE REMOTE BASE ---

echo "🌐 Creating empty base branch on upstream..."
git push upstream main:refs/heads/"$NEW_BRANCH"

# Creating local release branch
git checkout -b "$NEW_BRANCH"

# --- 4. TEXT REPLACEMENTS ---

echo "🔍 Replacing task runner image..."
# Using gsed logic (no empty quotes)
grep -rlI --exclude-dir=".git" --exclude="$SCRIPT_NAME" "quay.io/redhat-appstudio/rhtap-task-runner:latest" . | xargs sed -i "s|quay.io/redhat-appstudio/rhtap-task-runner:latest|quay.io/redhat-tssc/task-runner:${NEW_VERSION}|g" || true

echo "🛠️ Rendering all templates..."
make install-deps && make refresh

echo "📂 Changing tekton files..."
MODIFIED_VERSION=$(echo "${NEW_VERSION}" | tr '.' '-')
TARGET_DIR=".tekton"

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: $TARGET_DIR directory not found."
    exit 1
fi

find "$TARGET_DIR" -type f \( -name "*.yaml" \) | while read -r FILE; do
    OLD_FILENAME=$(basename "$FILE")
    NEW_FILENAME=$(echo "$OLD_FILENAME" | sed 's/rhtap/tssc/g')

    # Content replacement
    sed -i \
        -e "s/\"main\"/\"${NEW_BRANCH}\"/g" \
        -e "s/${OLD_FILENAME}/${NEW_FILENAME}/g" \
        -e "s/rhtap-task-runner/tssc-task-runner-${MODIFIED_VERSION}/g" \
        "$FILE"

    # Physical rename
    if [ "$OLD_FILENAME" != "$NEW_FILENAME" ]; then
        mv "$FILE" "$(dirname "$FILE")/$NEW_FILENAME"
    fi
done

echo "📂 Propagating changes to samples..."
./hack/copy-to-tssc-templates

echo "📝 Updating properties file..."
sed -i "s/export PIPELINE__REPO__BRANCH=main/export PIPELINE__REPO__BRANCH=${NEW_BRANCH}/g" samples/properties

echo "⚙️ Updating Pac references..."
./samples/generate.sh

# --- 5. COMMIT AND PUSH ---

echo "💾 Committing changes..."
git add .tekton
git commit -a -m "Release changes for ${NEW_BRANCH}" --signoff

echo "⬆️ Pushing to origin..."
git push origin "$NEW_BRANCH"

# --- 6. PR CREATION & VALIDATION ---

GIT_USER=$(gh api user -q .login)

echo "📨 Creating Pull Request..."
PR_URL=$(gh pr create \
    --repo redhat-appstudio/tssc-dev-multi-ci \
    --title "Release changes for ${NEW_VERSION}" \
    --body "Automated release update for version ${NEW_VERSION}." \
    --head "${GIT_USER}:${NEW_BRANCH}" \
    --base "${NEW_BRANCH}")

echo "✅ PR Created: $PR_URL"
echo "👀 Please check the PR in your browser."

read -p "Does the PR look correct? (y/n): " pr_confirm

if [[ $pr_confirm != [yY] ]]; then
    echo "⚠️ Reverting changes and deleting branches..."
    gh pr close "$PR_URL" --repo redhat-appstudio/tssc-dev-multi-ci --comment "Closing due to user cancellation." || true
    git push upstream --delete "$NEW_BRANCH" || true
    git push origin --delete "$NEW_BRANCH" || true
    git checkout main
    git branch -D "$NEW_BRANCH"
    echo "🧹 Cleanup complete. Remote and local state restored."
else
    echo "🎉 Release process finished successfully!"
fi
