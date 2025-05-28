# Generated from templates/build-pipeline-steps.sh.njk. Do not edit directly.

run rhtap/init.sh
run rhtap/buildah-rhtap.sh
run rhtap/cosign-sign-attest.sh
run rhtap/update-deployment.sh
run rhtap/acs-deploy-check.sh
run rhtap/acs-image-check.sh
run rhtap/acs-image-scan.sh
run rhtap/show-sbom-rhdh.sh
run rhtap/summary.sh
