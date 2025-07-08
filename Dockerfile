FROM registry.redhat.io/rhtas/cosign-rhel9:1.2.0@sha256:cb53dcc3bc912dd7f12147f33af1b435eae5ff4ab83b85c0277b4004b20a0248 as cosign

FROM registry.redhat.io/rhtas/ec-rhel9:0.6@sha256:34a7be862ef23c44526ed84bb4f228ffc6c87e15d3e09803546c46bb9cd22d97 as ec

FROM registry.redhat.io/ubi10/go-toolset:1.23@sha256:050c556adbf8a684de705abadfdfaf105936e5b4e7abe4f46d6b095a684bfa37 as go-builder

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

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6@sha256:92b1d5747a93608b6adb64dfd54515c3c5a360802db4706765ff3d8470df6290

# required per https://github.com/release-engineering/rhtap-ec-policy/blob/main/data/rule_data.yml
LABEL com.redhat.component="rhtap-task-runner"
LABEL name="rhtap-task-runner"
LABEL version="1.6.0"
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

