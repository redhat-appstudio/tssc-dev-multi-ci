#!/bin/bash

# Script to customize RHADS sample templates with forked repositories for pipelines
# and customized app deployment namespace in templates

set -euo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOTDIR=$(realpath $SCRIPTDIR/../..)

DRY_RUN="false" # Default to false, can be overridden by --dry-run flag

# Default values for customization flags
UPDATE_PIPELINE_REF="${UPDATE_PIPELINE_REF:-true}"

# Variable for customizing default app namespace (optional)
DEFAULT_APP_NAMESPACE="${DEFAULT_APP_NAMESPACE:-}"

SRC_TEKTON=$ROOTDIR/skeleton/ci/source-repo/tekton/.tekton
GITOPS_TEKTON=$ROOTDIR/skeleton/ci/gitops-template/tekton/.tekton
TEMPLATES_DIR=$ROOTDIR/templates

export PROPERTIES_FILE="$ROOTDIR/properties"

# Git current repository information
CURRENT_GIT_ORG=""
CURRENT_GIT_REPO=""
CURRENT_GIT_BRANCH=""

TARGET_PATHS=(
    "$SRC_TEKTON"
    "$GITOPS_TEKTON"
    "$TEMPLATES_DIR"
)

# Function to log messages
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Function to get and store git repository information
get_git_info() {
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null) || { log "ERROR" "Git remote 'origin' not found"; return 1; }
    
    if [[ $remote_url =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
        CURRENT_GIT_ORG="${BASH_REMATCH[1]}"
        CURRENT_GIT_REPO="${BASH_REMATCH[2]%.git}"
        CURRENT_GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    else
        log "ERROR" "Invalid repository URL format: $remote_url"
        return 1
    fi
}

# Function to run automated git workflow
run_automated_git_workflow() {
    echo -e "\n--- Automated Git Commit ---\n"
    
    local files_staged=0
    for path in "${TARGET_PATHS[@]}"; do
        if git status --porcelain "$path" 2>/dev/null | grep -q "^"; then
            git add "$path"
            log "INFO" "Staged $path"
            files_staged=$((files_staged + 1))
        fi
    done
    
    if [[ $files_staged -eq 0 ]]; then
        log "WARN" "No changes to stage"
        return 1
    fi
    
    if ! git commit -m "Customize templates for ${CURRENT_GIT_ORG}"; then
        log "ERROR" "Failed to commit changes"
        return 1
    fi
    log "INFO" "✅ Committed changes"
    
    if git push origin "${CURRENT_GIT_BRANCH}"; then
        log "INFO" "✅ Pushed to branch: ${CURRENT_GIT_BRANCH}"
    else
        log "WARN" "Push failed. Run manually: git push origin ${CURRENT_GIT_BRANCH}"
    fi
}

# Function to update Tekton pipeline references
update_tekton_definition() {
    echo -e "\n--- Updating Tekton pipeline references ---\n"
    
    log "INFO" "Setting pipeline repository to: $CURRENT_GIT_ORG/$CURRENT_GIT_REPO (branch: $CURRENT_GIT_BRANCH)"
    
    # Update properties file with current repository URLs and branch
    sed -i "s|^export PIPELINE__REPO__URL=.*|export PIPELINE__REPO__URL=https://github.com/$CURRENT_GIT_ORG/$CURRENT_GIT_REPO|" "$PROPERTIES_FILE"
    sed -i "s|^export PIPELINE__REPO__BRANCH=.*|export PIPELINE__REPO__BRANCH=$CURRENT_GIT_BRANCH|" "$PROPERTIES_FILE"
    log "INFO" "✅ Properties file updated"

    if "$ROOTDIR/scripts/update-tekton-definition"; then
        log "INFO" "✅ Tekton pipeline references updated successfully"
    else
        log "ERROR" "Failed to update Tekton pipeline references"
        return 1
    fi
}

# Function to update customize app namespace
update_app_namespace_in_templates() {
    echo -e "\n--- Update Namespace and Templates ---\n"

    local namespace_value=$1
    sed -i "s|^export DEFAULT__DEPLOYMENT__NAMESPACE__PREFIX=.*|export DEFAULT__DEPLOYMENT__NAMESPACE__PREFIX=$namespace_value|" "$PROPERTIES_FILE"
    log "INFO" "Updated DEFAULT__DEPLOYMENT__NAMESPACE__PREFIX to $namespace_value"
    
    if "$ROOTDIR/scripts/update-templates"; then
        log "INFO" "✅ update-templates script completed successfully"
    else
        log "ERROR" "❌ update-templates script failed"
        return 1
    fi
}

# Function to check all prerequisites
check_prerequisites() {
    echo -e "\n--- Prerequisites Check ---\n"
    
    # Check: Repository is not upstream
    if [[ "$CURRENT_GIT_ORG" == "redhat-appstudio" ]]; then
        log "ERROR" "❌ Cannot run on upstream repo. Please use your fork."
        return 1
    fi
    log "INFO" "✅ Repository is a fork"
}

# Function to display usage
usage() {
    echo ""
    echo "Script to customize RHADS sample templates with forked repositories and customize app namespace"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  --dry-run               Run in dry-run mode (only update files, don't commit/push)"
    echo ""
    echo "Environment Variables(optional):"
    echo "  UPDATE_PIPELINE_REF     Update Tekton pipeline references (default: true)"
    echo "  DEFAULT_APP_NAMESPACE   Customize default deployment namespace prefix (optional)"
    echo ""
}

# Function to parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        local arg=$1
        case $arg in
            -h|--help)
                usage
                exit 0
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $arg"
                usage
                exit 1
                ;;
        esac
    done
}

main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    echo ""
    echo "=========================================="
    echo "  RHADS Sample Templates Customization"
    echo "=========================================="
    echo ""
    
    echo "Configuration:"
    echo "  Dry Run:                    $DRY_RUN"
    echo "  Update Pipeline References: $UPDATE_PIPELINE_REF"
    if [[ -n "${DEFAULT_APP_NAMESPACE:-}" ]]; then
        echo "  Update Custom Namespace:    $DEFAULT_APP_NAMESPACE"
    fi
    
    # Step 1: Get git repository information once (exported for all functions)
    log "INFO" "Getting git repository information..."
    if ! get_git_info; then
        log "ERROR" "Failed to get git repository information, exiting"
        exit 1
    fi
    log "INFO" "Current Repository: $CURRENT_GIT_ORG/$CURRENT_GIT_REPO (branch: ${CURRENT_GIT_BRANCH})"
    
    # Step 2: Check prerequisites before proceeding
    if ! check_prerequisites; then
        log "ERROR" "Prerequisites check failed, exiting"
        exit 1
    fi
    
    # Step 3: Update Tekton pipeline references
    if [[ "$UPDATE_PIPELINE_REF" == "true" ]]; then
        if ! update_tekton_definition; then
            log "ERROR" "Failed to update Tekton pipeline references"
            exit 1
        fi
    else
        log "INFO" "Skipping Tekton pipeline reference update (UPDATE_PIPELINE_REF=false)"
    fi
    
    # Step 4: Update namespace and run update-templates if DEFAULT_APP_NAMESPACE is set
    if [[ -n "${DEFAULT_APP_NAMESPACE:-}" ]]; then
        if ! update_app_namespace_in_templates "$DEFAULT_APP_NAMESPACE"; then
            log "ERROR" "Failed to update default app namespace to $DEFAULT_APP_NAMESPACE"
            exit 1
        fi
    else
        log "INFO" "Skipping namespace update (DEFAULT_APP_NAMESPACE not set)"
    fi
    
    # Step 5: Commit and push changes (unless dry run)
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Dry run mode enabled - skipping commit and push"
    else
        if run_automated_git_workflow; then
            log "INFO" "Automated git workflow completed successfully"
        else
            log "WARN" "Automated git workflow failed"
            log "INFO" "Manually commit and push the changes to your organization"
        fi
    fi
    
    echo -e "\n--- ✅ Customization Completed Successfully ---\n"
    echo "Your Developer Hub catalog url:"
    echo " https://github.com/${CURRENT_GIT_ORG}/${CURRENT_GIT_REPO}/blob/${CURRENT_GIT_BRANCH}/samples/all.yaml"
}

# Run main workflow with all arguments
main "$@"
