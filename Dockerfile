FROM registry.redhat.io/rhtas/cosign-rhel9:1.2.0@sha256:cb53dcc3bc912dd7f12147f33af1b435eae5ff4ab83b85c0277b4004b20a0248 as cosign

FROM registry.redhat.io/rhtas/ec-rhel9:0.6@sha256:34a7be862ef23c44526ed84bb4f228ffc6c87e15d3e09803546c46bb9cd22d97 as ec

FROM registry.redhat.io/openshift4/ose-cli:latest@sha256:ef83967297f619f45075e7fd1428a1eb981622a6c174c46fb53b158ed24bed85 as oc

# Ideally, use the official image from Red Hat, e.g. registry.access.redhat.com/ubi10/go-toolset,
# but a 1.24 release does not yet exist.
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24@sha256:beed4519c775d6123c11351048be29e6f93ab0adaea2c7d55977b445966f5b27 as go-builder

WORKDIR /build

COPY ./tools .

ENV GOBIN=/usr/local/bin/

USER root

RUN \
  cd yq && \
  go install -trimpath --mod=readonly github.com/mikefarah/yq/v4 && \
  yq --version

RUN \
  cd syft && \
  go install -trimpath --mod=readonly github.com/anchore/syft/cmd/syft && \
  syft version

RUN \
  cd splashy && \
  go install -trimpath --mod=readonly github.com/redhat-appstudio/tssc-dev-multi-ci/tools/splashy

RUN \
  cd git-clone/image/git-init && \
  go build -trimpath -o /usr/local/bin/git-init

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6-1760515502@sha256:34880b64c07f28f64d95737f82f891516de9a3b43583f39970f7bf8e4cfa48b7

# required per https://github.com/release-engineering/rhtap-ec-policy/blob/main/data/rule_data.yml
LABEL com.redhat.component="rhtap-task-runner"
LABEL name="rhtap-task-runner"
LABEL version="1.5.0"
LABEL release="1"
LABEL summary="RHTAP Task Runner"
LABEL description="A collection of CLI tools and scripts needed for RHTAP pipelines"
LABEL io.k8s.display-name="RHTAP Task Runner"
LABEL io.k8s.description="A collection of CLI tools and scripts needed for RHTAP pipelines"
LABEL vendor="Red Hat, Inc."
LABEL url="https://github.com/redhat-appstudio/tssc-dev-multi-ci"
LABEL distribution-scope="public"
LABEL io.openshift.tags=""

RUN \
  microdnf -y --nodocs --setopt=keepcache=0 install which git-core jq python3.11 podman buildah podman fuse-overlayfs findutils && \
  ln -s /usr/bin/python3.11 /usr/bin/python3

COPY --from=cosign /usr/local/bin/cosign /usr/bin/cosign
COPY --from=ec /usr/local/bin/ec /usr/bin/ec
COPY --from=ec /usr/local/bin/reduce-snapshot.sh /usr/bin/reduce-snapshot.sh
COPY --from=oc /usr/bin/oc /usr/bin/oc
COPY --from=go-builder /usr/local/bin/yq /usr/bin/yq
COPY --from=go-builder /usr/local/bin/syft /usr/bin/syft
COPY --from=go-builder /usr/local/bin/splashy /usr/bin/splashy
COPY --from=go-builder /usr/local/bin/git-init /usr/bin/git-init

# The git-clone Task expects the `git-init` binary to be available at a specific location, instead
# of relying on $PATH.
RUN mkdir -p /ko-app && ln -s /usr/bin/git-init /ko-app/git-init

WORKDIR /work

COPY ./rhtap ./rhtap/

COPY ./entrypoint.sh /usr/local/bin/

COPY ./tools/buildah-container/scripts/utils/retry-func.sh /usr/bin/retry

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
