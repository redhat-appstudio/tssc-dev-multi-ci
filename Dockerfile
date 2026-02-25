FROM registry.redhat.io/rhtas/cosign-rhel9:1.3.2@sha256:a8289d488491991d454a32784de19476f2c984917eb7a33b4544e55512f2747c as cosign

FROM registry.redhat.io/rhtas/ec-rhel9:0.7@sha256:d864cad870adad9df23ce860e8c31eb86f61201b408ed00d01fec00714569fd1 as ec

FROM registry.redhat.io/openshift4/ose-cli:latest@sha256:ef83967297f619f45075e7fd1428a1eb981622a6c174c46fb53b158ed24bed85 as oc

# Since this is a tech preview image we should double check with TPA team this on next release cycle
FROM registry.redhat.io/rh-syft-tech-preview/syft-rhel9:1.29.0-1756223792@sha256:15ed82f0b5311a570ccb8ea02135d9776c6d61e545c51b256b3fc5b5db20ba67 as syft

FROM registry.access.redhat.com/ubi10/go-toolset:1.25.7-1771345385@sha256:cba9484f1b22d86b306afebf1db5f42b968ae3130aef7d99c83de753a016d0a7 as go-builder

WORKDIR /opt/app-root/src

COPY ./tools .

ENV GOBIN=/usr/local/bin/

USER root

RUN \
  cd yq && \
  go install -trimpath --mod=readonly github.com/mikefarah/yq/v4 && \
  yq --version

RUN \
  cd splashy && \
  go install -trimpath --mod=readonly github.com/redhat-appstudio/tssc-dev-multi-ci/tools/splashy

RUN \
  cd git-clone/image/git-init && \
  go build -trimpath -o /usr/local/bin/git-init

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.7-1771346502@sha256:c7d44146f826037f6873d99da479299b889473492d3c1ab8af86f08af04ec8a0

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
COPY --from=syft /usr/local/bin/syft /usr/bin/syft
COPY --from=go-builder /usr/local/bin/yq /usr/bin/yq
COPY --from=go-builder /usr/local/bin/splashy /usr/bin/splashy
COPY --from=go-builder /usr/local/bin/git-init /usr/bin/git-init

# The git-clone Task expects the `git-init` binary to be available at a specific location, instead
# of relying on $PATH.
RUN mkdir -p /ko-app && ln -s /usr/bin/git-init /ko-app/git-init

WORKDIR /work

COPY ./tssc ./tssc/

COPY ./entrypoint.sh /usr/local/bin/

COPY ./tools/buildah-container/scripts/utils/retry-func.sh /usr/bin/retry

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
