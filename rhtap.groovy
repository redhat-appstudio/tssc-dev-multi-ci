/* Generated from templates/rhtap.groovy.njk. Do not edit directly. */

def info(message) {
    echo "INFO: ${message}"
}

def install_script (scriptname) {
    echo ("Loading libraryResource(${scriptname})")
    contents = libraryResource( scriptname )
    writeFile(file:  "rhtap/${scriptname}"  , text: contents)
    sh "chmod +x rhtap/${scriptname}"
}

def run_script (scriptname) {
    // load common utilities across all tasks
    install_script ("common.sh")
    install_script ("verify-deps-exist")

    if (scriptname == 'buildah-rhtap.sh') {
      // Called from buildah-rhtap.sh
      install_script ('merge_sboms.py')
    }

    install_script (scriptname)
    sh "rhtap/${scriptname}"
}

def init( ) {
    run_script ('init.sh')
}

def buildah_rhtap( ) {
    run_script ('buildah-rhtap.sh')
}

def cosign_sign_attest( ) {
    run_script ('cosign-sign-attest.sh')
}

def acs_deploy_check( ) {
    run_script ('acs-deploy-check.sh')
}

def acs_image_check( ) {
    run_script ('acs-image-check.sh')
}

def acs_image_scan( ) {
    run_script ('acs-image-scan.sh')
}

def update_deployment( ) {
    run_script ('update-deployment.sh')
}

def show_sbom_rhdh( ) {
    run_script ('show-sbom-rhdh.sh')
}

def summary( ) {
    run_script ('summary.sh')
}

def gather_deploy_images( ) {
    run_script ('gather-deploy-images.sh')
}

def verify_enterprise_contract( ) {
    run_script ('verify-enterprise-contract.sh')
}
