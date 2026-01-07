# RHTAP standard pipelines

These pipelines are in standard tekton format.
They can be found in ./pac/pipelines and ./pac/tasks.

## Maintenance Model

This repository maintains its own pipelines and most tasks. Only 3 tasks are synchronized from the [build-definitions](https://github.com/redhat-appstudio/build-definitions) repository:
- `init` - Initialize pipeline task with rebuild flags
- `git-clone` - Clone source repository
- `summary` - Pipeline summary and reporting

All other tasks and all pipelines are maintained directly in this repository. To update the synchronized tasks, run:
```bash
hack/import-build-definitions
```

# Installation and usage

Depending on the use case there are two ways of consuming of the RHTAP pipeline:
 - [consuming unmodified pipeline](#consuming-unmodified-pipeline)
 - [consuming customized pipeline](#consuming-customized-pipeline)

## Consuming unmodified pipelines

For this scenario, the RHTAP [pipeline definition](https://github.com/redhat-appstudio/tssc-dev-multi-ci/blob/main/samples/tekton/pac/pipelines/docker-build-rhtap.yaml) can be directly referenced from the [official](https://github.com/redhat-appstudio/tssc-dev-multi-ci) repository.
In such case, all the updates and security pathes provided will be available immediately to the consuming pipelines. No actions required from the consumer side.

In the pipelines as code runners, you can find the reference to these pipelines in the following format. See a full pipeline runner example [here](https://github.com/redhat-appstudio/tssc-dev-multi-ci/blob/main/samples/tekton/pac/source-repo/docker-push.yaml)

```
    pipelinesascode.tekton.dev/pipeline: "raw-url-with-branch/pac/pipelines/docker-build-rhtap.yaml"
    pipelinesascode.tekton.dev/task-0: "raw-url-with-branch/pac/tasks/init.yaml"
```

The placeholder `raw-url-with-branch` would have a reference to the original pipelines repository or a forked versions in raw reference format, or blob format for github enterprise.  
`https://raw.githubusercontent.com/redhat-appstudio/tssc-dev-multi-ci/release-v1.9.x/samples/tekton`

To pin your usage to an older release choose the specific version you would like. 


## Consuming customized pipelines

If any customization to the default RHTAP [pipeline definition](https://github.com/redhat-appstudio/tssc-dev-multi-ci/blob/main/samples/tekton/pac/pipelines/docker-build-rhtap.yaml) is needed or immediate updates are not desired, workflow described in this section should be taken.

Fork this repository and modify the default RHTAP pipeline definition according to your needs.
Reference the modified version of the pipeline.

Replace `raw-url-with-branch` would have a reference to the original pipelines repository or a forked versions in raw reference format, or blob format for github enterprise.

 `https://raw.githubusercontent.com/MY_ORG/tssc-dev-multi-ci/release-v1.9.x/samples/tekton`

To consume CVE fixes and pipeline updates in the upstream, one should rebase changes in the fork on top of the new RHTAP pipeline version. You can validate these in a branch before rolling out to your internal users. 

## Backstage

Modify the template placeholders to match your backstage template vars
Note, PaC also has `{{variables}}` and you should not modify those.

   - `{{values.appName}} -> ${{ values.appName }}`
   - `{{values.dockerfileLocation}}-> ${{ values.dockerfileLocation }} `
   - `{{values.namespace}}-> ${{ values.namespace }} `
   - `{{values.image}}-> ${{ values.image }} `
   - `{{values.namespace}}-> ${{ values.namespace }} `
   - `{{values.buildContext}}-> ${{ values.buildContext }} `
   - `{{values.repoURL}}-> ${{values.repoURL}}`
