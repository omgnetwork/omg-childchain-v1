#!/bin/sh

set -e

echo_info() {
    printf "\\033[0;34m%s\\033[0;0m\\n" "$1"
}

echo_warn() {
    printf "\\033[0;33m%s\\033[0;0m\\n" "$1"
}


## Sanity check
##

if [ -z "$CIRCLE_GPG_KEY" ] ||
       [ -z "$CIRCLE_GPG_OWNERTRUST" ] ||
       [ -z "$GCLOUD_SERVICE_KEY" ]; then
    echo_warn "Deploy credentials not present, skipping deploy."
    exit 0
fi


## GPG
##

GPGFILE=$(mktemp)
trap 'rm -f $GPGFILE' 0 1 2 3 6 14 15
echo "$CIRCLE_GPG_KEY" | base64 -d | gunzip > "$GPGFILE"
gpg --import "$GPGFILE"
printf "%s\\n" "$CIRCLE_GPG_OWNERTRUST" | gpg --import-ownertrust


## GCP
##

echo $GCLOUD_SERVICE_KEY | gcloud auth activate-service-account --key-file=-
gcloud beta container clusters get-credentials ${GCP_CLUSTER_DEVELOPMENT} --region ${GCP_REGION} --project ${GCP_PROJECT}
image_tag="$(printf "%s" "$CIRCLE_SHA1" | head -c 7)"

kubectl set image statefulset childchain childchain=omisego/child_chain:${image_tag}
while true; do if [ "$(kubectl get pods childchain-0 -o jsonpath=\"{.status.phase}\" | grep Running)" ]; then break; fi; done


