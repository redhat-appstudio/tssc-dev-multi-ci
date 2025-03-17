# Disable built in rule for .sh files
MAKEFLAGS += -r

# A list of files that are built from templates
FILES=\
  generated/source-repo/jenkins/Jenkinsfile \
  generated/source-repo/githubactions/.github/workflows/build-and-update-gitops.yml \
  generated/source-repo/gitlabci/.gitlab-ci.yml \
  \
  generated/gitops-template/jenkins/Jenkinsfile \
  generated/gitops-template/githubactions/.github/workflows/gitops-promotion.yml \
  generated/gitops-template/gitlabci/.gitlab-ci.yml \
  \
  rhtap.groovy \
  rhtap/build-pipeline-steps.sh \
  rhtap/promote-pipeline-steps.sh \
  \

RENDER=node ./render/render.cjs

# Build
.PHONY: build
build: $(FILES)

# Force a rebuild
.PHONY: refresh
refresh: clean build

# Shared build recipe for generated a file from a template
define build_recipe
	@echo "Building $@"
	@mkdir -p $$(dirname $@)
	@$(RENDER) $< templates/data.yaml targetFile=$@ templateFile=$< > $@
endef

# Reduce repetition in this file by creating a template
TARGET_DIRS=\
  jenkins \
  githubactions/.github/workflows \
  gitlabci

define targets_for_ci_type
generated/source-repo/$(1)/%: templates/source-repo/%.njk templates/data.yaml
	$$(build_recipe)

generated/gitops-template/$(1)/%: templates/gitops-template/%.njk templates/data.yaml
	$$(build_recipe)

endef

# Create the targets each CI type
$(foreach target_dir,$(TARGET_DIRS),$(eval $(call targets_for_ci_type,$(target_dir))))

# For the two pipeline-steps.sh files
rhtap/%: templates/%.njk templates/data.yaml
	$(build_recipe)

# For rhtap.groovy
%: templates/%.njk templates/data.yaml
	$(build_recipe)

# This should produce a non-zero exit code if there are
# generated files that are not in sync with the templates
.PHONY: ensure-fresh
ensure-fresh:
	@$(MAKE) refresh > /dev/null && git diff --exit-code -- $(FILES)

# Remove generated files
.PHONY: clean
clean:
	@rm -f $(FILES)

# Install required node modules
.PHONY: install-deps
install-deps:
	@npm --prefix ./render install --frozen-lockfile

#-----------------------------------------------------------------------------

SHFMT_VER=v3.10.0
SHFMT_URL=https://github.com/mvdan/sh/releases/download/$(SHFMT_VER)/shfmt_$(SHFMT_VER)_linux_amd64
SHFMT=bin/shfmt
SHFMT_OPTS=--indent 4 --space-redirects

$(SHFMT):
	@mkdir -p $$(dirname $(SHFMT))
	curl -sLo $@ $(SHFMT_URL) && chmod 755 $@

.PHONY: install-shfmt
install-shfmt: $(SHFMT)

# Need to skip env.template.sh files because the formatter
# chokes on the ${{...}} Nunjucks delimiters
define all_scripts
	$$( \
	  git ls-files *.sh && \
	  git ls-files rhtap/*.sh | grep -v env.template.sh && \
	  git grep -l '^#!/bin/bash' hack \
	)
endef

# Format all bash scripts
.PHONY: format
format: $(SHFMT)
	@$(SHFMT) $(SHFMT_OPTS) --write $(all_scripts)

# Fails if any formatting diff is found
.PHONY: ensure-formatted
ensure-formatted: $(SHFMT)
	@$(SHFMT) $(SHFMT_OPTS) --diff $(all_scripts)

#-----------------------------------------------------------------------------

# Run this locally before pushing your PR.
# (See also .github/workflows/checks.yml)
.PHONY: ci
ci: ensure-fresh ensure-formatted

#-----------------------------------------------------------------------------

.PHONY: build-push-image
build-push-image: build-image push-image

#
# The default quay org is your current user, or MY_QUAY_USER if that is present.
# To set it to something else do this for example:
#
#   export RUNNER_IMAGE_ORG=myorg
#   make push-images
#
# or:
#   RUNNER_IMAGE_QUAY_ORG=myorg make push-images
#
# You can set RUNNER_IMAGE_REPO similarly if you want to use a
# different repo.
#
# (Note that the real production quay org is redhat-appstudio.)
#
MY_QUAY_USER ?= $(USER)
RUNNER_IMAGE_ORG ?= $(MY_QUAY_USER)
RUNNER_IMAGE_REPO ?= rhtap-task-runner

TAG_PREFIX=dev

define floating-tag
	quay.io/$(RUNNER_IMAGE_ORG)/$(RUNNER_IMAGE_REPO):$(TAG_PREFIX)
endef

define unique-tag
	quay.io/$(RUNNER_IMAGE_ORG)/$(RUNNER_IMAGE_REPO):$(TAG_PREFIX)-$(shell git rev-parse --short HEAD)
endef

# Todo: Check for uncommited changes before pushing
.PHONY: push-image
push-image:
	podman push $(unique-tag)
	podman push $(floating-tag)
	@echo Pushed to https://quay.io/repository/$(RUNNER_IMAGE_ORG)/$(RUNNER_IMAGE_REPO)?tab=tags

.PHONY: build-image
build-image:
	podman build $(if $(NOCACHE),--no-cache) -f Dockerfile -t $(floating-tag) --platform linux/amd64
	podman tag $(floating-tag) $(unique-tag)

.PHONY: run-image
run-image:
	podman run --rm -i -t $(floating-tag)
