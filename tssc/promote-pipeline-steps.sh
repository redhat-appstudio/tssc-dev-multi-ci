# Generated from templates/promote-pipeline-steps.sh.njk. Do not edit directly.

run tssc/gather-deploy-images.sh
run tssc/verify-conforma.sh
run tssc/gather-images-to-upload-sbom.sh
run tssc/download-sbom-from-url-in-attestation.sh
run tssc/upload-sbom-to-trustification.sh
