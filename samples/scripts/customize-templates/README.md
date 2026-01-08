# Customize Templates

The `customize.sh` script customizes Red Hat Advanced Developer Suite (RHADS) sample software templates by updating Tekton pipeline references to point to your forked repository and optionally updating the default app namespace.

[Here](https://docs.redhat.com/en/documentation/red_hat_advanced_developer_suite_-_software_supply_chain/1.8/html/customizing_red_hat_advanced_developer_suite_-_software_supply_chain/customizing-sample-pipelines_default) is the reference document.


## How the Script Works

The `customize.sh` script performs these steps:

1. **Verifies prerequisites**: Checks repository is a fork (not upstream)
2. **Updates Tekton pipeline references** (if `UPDATE_PIPELINE_REF=true`): Updates pipeline URLs in properties file and regenerates `.tekton/` directories
3. **Updates namespace** (if `DEFAULT_APP_NAMESPACE` is set): Updates namespace in properties file and regenerates templates
4. **Commits and pushes changes** (unless `--dry-run`): Automatically stages, commits, and pushes all changes


## Prerequisites

Before running the script, ensure you have:

1. **Forked the templates repository**: Fork and clone [tssc-dev-multi-ci](https://github.com/redhat-appstudio/tssc-dev-multi-ci)
2. **Git push access**: SSH keys or credentials configured for pushing to your fork


## Command-Line Options

- **`-h, --help`**: Show help message and exit
- **`--dry-run`**: Only update files, don't commit/push changes

```bash
$ ./scripts/customize-templates/customize.sh -h

Script to customize RHADS sample templates with forked repositories and customize app namespace

Usage: ./samples/scripts/customize-templates/customize.sh [OPTIONS]

Options:
  -h, --help              Show this help message
  --dry-run               Run in dry-run mode (only update files, don't commit/push)

Environment Variables(optional):
  UPDATE_PIPELINE_REF     Update Tekton pipeline references (default: true)
  DEFAULT_APP_NAMESPACE   Customize default deployment namespace prefix (optional)
```

## Steps to Run the Script

### 1. Fork and Clone Repository

```bash
# Fork the repository on GitHub (via web interface)
# Then clone your forked repository
git clone https://github.com/<your-org>/tssc-dev-multi-ci.git
cd tssc-dev-multi-ci/samples
```

### 2. Sync with Upstream and Create Branch

Add upstream remote and rebase with the desired upstream branch:

```bash
# Add upstream remote (if not already added)
git remote add upstream https://github.com/redhat-appstudio/tssc-dev-multi-ci.git

# Fetch upstream branches
git fetch upstream

# Rebase with upstream branch (use main or a release branch like release-v1.8.x)
git rebase upstream/main
# git rebase upstream/release-v1.8.x

# Create and checkout a customize branch
git checkout -b customize
```

### 3. Set Environment Variables (Optional)

```bash
# Optional: Customize default app namespace
export DEFAULT_APP_NAMESPACE=my-custom-namespace
```

### 4. Run the Script

```bash
# Run normally (commits and pushes changes automatically)
./scripts/customize-templates/customize.sh

# Run in dry-run mode (only updates files, doesn't commit/push)
./scripts/customize-templates/customize.sh --dry-run
```

### 5. Manual Commit (if using --dry-run)

If you ran with `--dry-run`, manually commit and push:

```bash
git status
git add <files>

# Commit the changes
git commit -m "Customize templates for your-org"

# Push the changes to your org
git push origin $(git branch --show-current)
```


## What Gets Updated

When `UPDATE_PIPELINE_REF=true`:
- `properties` file: `PIPELINE__REPO__URL` and `PIPELINE__REPO__BRANCH`
- `.tekton/` directories in `skeleton/ci/source-repo/` and `skeleton/ci/gitops-template/`

When `DEFAULT_APP_NAMESPACE` is set:
- `properties` file: `DEFAULT__DEPLOYMENT__NAMESPACE__PREFIX`
- Templates in `templates/` directory
