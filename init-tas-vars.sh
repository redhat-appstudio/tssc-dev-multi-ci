# init Tuf and REKOR
# for local build and CI we set REKOR_HOST and TUF_MIRROR

echo "Checking for REKOR and TUF"

# get hosts, if errors occur or cannot find routes, set to none
RT=$(oc get routes -n tssc-tas -o name 2> /dev/null | grep rekor-server)
if [[ $RT == "" ]]; then
    export REKOR_HOST=''
    export IGNORE_REKOR=true
else
    HOST=$(oc get -n tssc-tas $RT -o jsonpath={.spec.host})
    export REKOR_HOST=https://$HOST
    export IGNORE_REKOR=false
fi

RT=$(oc get routes -n tssc-tas -o name 2> /dev/null | grep tuf)
if [[ $RT == "" ]]; then
    export TUF_MIRROR=''
else
    HOST=$(oc get -n tssc-tas $RT -o jsonpath={.spec.host})
    export TUF_MIRROR=https://$HOST
fi

echo "REKOR_HOST set to $REKOR_HOST"
echo "TUF_MIRROR set to $TUF_MIRROR"
echo "IGNORE_REKOR set to $IGNORE_REKOR"
