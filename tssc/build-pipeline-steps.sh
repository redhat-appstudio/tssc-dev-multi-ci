# Generated from templates/build-pipeline-steps.sh.njk. Do not edit directly.

run tssc/init.sh
run tssc/buildah-tssc.sh
run tssc/cosign-sign-attest.sh
run tssc/update-deployment.sh
run tssc/acs-deploy-check.sh
run tssc/acs-image-check.sh
run tssc/acs-image-scan.sh
run tssc/show-sbom-rhdh.sh
run tssc/summary.sh
