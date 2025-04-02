FROM registry.redhat.io/rhtas/cosign-rhel9:1.1.1@sha256:3cd261cd4fed03688c6fd3c6161ae1ec69e908bbb6593ec279415414c7422535 as cosign

FROM registry.redhat.io/rhtas/ec-rhel9:0.6@sha256:e7f3cefadd1f4a65f242fb0b86f8083bbb17a91fd65f2ae65d128b7937d3e736 as ec

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23@sha256:0a070e4a8f2698b6aba3630a49eb995ff1b0a182d0c5fa264888acf9d535f384 as go-builder

WORKDIR /build

COPY ./tools .

ENV GOBIN=/usr/local/bin/

RUN \
  cd yq && \
  go install -trimpath --mod=readonly github.com/mikefarah/yq/v4 && \
  yq --version

RUN \
  cd syft && \
  go install -trimpath --mod=readonly github.com/anchore/syft/cmd/syft && \
  syft version

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.5@sha256:ac61c96b93894b9169221e87718733354dd3765dd4a62b275893c7ff0d876869

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
COPY --from=go-builder /usr/local/bin/yq /usr/bin/yq
COPY --from=go-builder /usr/local/bin/syft /usr/bin/syft

WORKDIR /work

COPY ./rhtap ./rhtap/

CMD ["/bin/bash"]
