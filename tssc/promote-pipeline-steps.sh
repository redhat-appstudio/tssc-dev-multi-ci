# Generated from templates/promote-pipeline-steps.sh.njk. Do not edit directly.

run rhtap/gather-deploy-images.sh
run rhtap/verify-enterprise-contract.sh
run rhtap/gather-images-to-upload-sbom.sh
run rhtap/download-sbom-from-url-in-attestation.sh
run rhtap/upload-sbom-to-trustification.sh
