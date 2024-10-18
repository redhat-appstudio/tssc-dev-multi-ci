# init tuf and REKOR

RT=$(oc get routes -n rhtap-tas -o name | grep rekor-server)
HOST=$(oc get -n rhtap-tas $RT -o jsonpath={.spec.host})
export REKOR_HOST=https://$HOST


RT=$(oc get routes -n rhtap-tas -o name | grep tuf)
HOST=$(oc get -n rhtap-tas $RT -o jsonpath={.spec.host})
export TUF_MIRROR=https://$HOST


echo "REKOR_HOST set to $REKOR_HOST"
echo "TUF_MIRROR set to $TUF_MIRROR"


