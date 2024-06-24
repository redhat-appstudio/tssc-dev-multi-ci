apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  labels:
    pipelines.openshift.io/runtime: generic
    pipelines.openshift.io/strategy: docker
    pipelines.openshift.io/used-by: build-cloud
  name: docker-build-rhtap
spec:
  finally:
    - name: show-sbom
      params:
        - name: IMAGE_URL
          value: $(tasks.build-container.results.IMAGE_URL)
      taskRef:
        name: show-sbom-rhdh
    - name: show-summary
      params:
        - name: pipelinerun-name
          value: $(context.pipelineRun.name)
        - name: git-url
          value: $(tasks.clone-repository.results.url)?rev=$(tasks.clone-repository.results.commit)
        - name: image-url
          value: $(params.output-image)
        - name: build-task-status
          value: $(tasks.build-container.status)
      taskRef:
        name: summary
      workspaces:
        - name: workspace
          workspace: workspace
  params:
    - description: Source Repository URL
      name: git-url
      type: string
    - default: ""
      description: Revision of the Source Repository
      name: revision
      type: string
    - description: Fully Qualified Output Image
      name: output-image
      type: string
    - default: .
      description: Path to the source code of an application's component from where to build image.
      name: path-context
      type: string
    - default: Dockerfile
      description: Path to the Dockerfile inside the context specified by parameter path-context
      name: dockerfile
      type: string
    - default: "false"
      description: Force rebuild image
      name: rebuild
      type: string
    - default: "false"
      description: Skip checks against built image
      name: skip-checks
      type: string
    - default: "false"
      description: Execute the build with network isolation
      name: hermetic
      type: string
    - default: ""
      description: Build dependencies to be prefetched by Cachi2
      name: prefetch-input
      type: string
    - default: "false"
      description: Java build
      name: java
      type: string
    - default: ""
      description: Image tag expiration time, time values could be something like 1h, 2d, 3w for hours, days, and weeks, respectively.
      name: image-expires-after
    - default: "false"
      description: Build a source image.
      name: build-source-image
      type: string
    - default: rox-api-token
      name: stackrox-secret
      type: string
    - default: gitops-auth-secret
      description: 'Secret name to enable this pipeline to update the gitops repo with the new image. '
      name: gitops-auth-secret-name
      type: string
    - default: push
      description: Event that triggered the pipeline run, e.g. push, pull_request
      name: event-type
      type: string
  results:
    - name: IMAGE_URL
      value: $(tasks.build-container.results.IMAGE_URL)
    - name: IMAGE_DIGEST
      value: $(tasks.build-container.results.IMAGE_DIGEST)
    - name: CHAINS-GIT_URL
      value: $(tasks.clone-repository.results.url)
    - name: CHAINS-GIT_COMMIT
      value: $(tasks.clone-repository.results.commit)
    - name: ACS_SCAN_OUTPUT
      value: $(tasks.acs-image-scan.results.SCAN_OUTPUT)
  tasks:
    - name: init
      params:
        - name: image-url
          value: $(params.output-image)
        - name: rebuild
          value: $(params.rebuild)
        - name: skip-checks
          value: $(params.skip-checks)
      taskRef:
        name: init
    - name: clone-repository
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.revision)
      runAfter:
        - init
      taskRef:
        name: git-clone
      when:
        - input: $(tasks.init.results.build)
          operator: in
          values:
            - "true"
      workspaces:
        - name: output
          workspace: workspace
        - name: basic-auth
          workspace: git-auth
    - name: build-container
      params:
        - name: IMAGE
          value: $(params.output-image)
        - name: DOCKERFILE
          value: $(params.dockerfile)
        - name: CONTEXT
          value: $(params.path-context)
        - name: IMAGE_EXPIRES_AFTER
          value: $(params.image-expires-after)
        - name: COMMIT_SHA
          value: $(tasks.clone-repository.results.commit)
      runAfter:
        - clone-repository
      taskRef:
        name: buildah-rhtap
      when:
        - input: $(tasks.init.results.build)
          operator: in
          values:
            - "true"
      workspaces:
        - name: source
          workspace: workspace
    - name: acs-image-check
      params:
        - name: rox-secret-name
          value: $(params.stackrox-secret)
        - name: image
          value: $(params.output-image)
        - name: insecure-skip-tls-verify
          value: "true"
        - name: image-digest
          value: $(tasks.build-container.results.IMAGE_DIGEST)
      runAfter:
        - build-container
      taskRef:
        name: acs-image-check
    - name: acs-image-scan
      params:
        - name: rox-secret-name
          value: $(params.stackrox-secret)
        - name: image
          value: $(params.output-image)
        - name: insecure-skip-tls-verify
          value: "true"
        - name: image-digest
          value: $(tasks.build-container.results.IMAGE_DIGEST)
      runAfter:
        - build-container
      taskRef:
        kind: Task
        name: acs-image-scan
    - name: acs-deploy-check
      params:
        - name: rox-secret-name
          value: $(params.stackrox-secret)
        - name: gitops-repo-url
          value: $(params.git-url)-gitops
        - name: insecure-skip-tls-verify
          value: "true"
      runAfter:
        - update-deployment
      taskRef:
        kind: Task
        name: acs-deploy-check
      when:
        - input: $(params.event-type)
          operator: notin
          values:
            - pull_request
            - Merge Request
    - name: update-deployment
      params:
        - name: gitops-repo-url
          value: $(params.git-url)-gitops
        - name: image
          value: $(tasks.build-container.results.IMAGE_URL)@$(tasks.build-container.results.IMAGE_DIGEST)
        - name: gitops-auth-secret-name
          value: $(params.gitops-auth-secret-name)
      runAfter:
        - build-container
      taskRef:
        kind: Task
        name: update-deployment
      when:
        - input: $(params.event-type)
          operator: notin
          values:
            - pull_request
            - Merge Request
  workspaces:
    - name: workspace
    - name: git-auth
      optional: true