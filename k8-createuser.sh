#!/bin/bash

#
# Install into an executable script on your path called kubectl-createuser, then
# you can use it as follows:
#
#  kubectl createuser lpabon
#
# Implementation of the blog: https://www.openlogic.com/blog/granting-user-access-your-kubernetes-cluster

# Replace with your organization
ORGANIZATION=org
cluster=app

# Creats a user in Kubernetes only. Use osd::createUserKubeconfig() instead to create a full
# kubeconfig for the new user.
function osd::createUser() {
    local username="$1"
    local location="$2"

    openssl req -new -newkey rsa:4096 -nodes \
        -keyout ${location}/${username}-k8s.key \
        -out ${location}/${username}-k8s.csr \
        -subj "/CN=${username}/O=${ORGANIZATION}"

    cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${username}-access
spec:
  request: $(cat ${location}/${username}-k8s.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth
EOF
    kubectl certificate approve ${username}-access
    kubectl get csr ${username}-access \
        -o jsonpath='{.status.certificate}' | base64 --decode > ${location}/${username}-kubeconfig.crt
}

# Creates a new Kubernetes user only able to access their namespace with the
# same name. The kubeconfig for this user must be passed in.
function osd::createUserKubeconfig() {
    local user="$1"
    local location="."
    local kubeconfig="${location}/${user}-kubeconfig.conf"

    osd::createUser "$user" "$location"

    kubectl config set-cluster $cluster \
        --server=$address \
        --certificate-authority=$cafile \
        --embed-certs=true \
        --kubeconfig=${kubeconfig}
    kubectl config set-credentials \
        ${user} \
        --client-certificate=${location}/${user}-kubeconfig.crt \
        --client-key=${location}/${user}-k8s.key \
        --embed-certs \
        --kubeconfig=${kubeconfig}
    kubectl create namespace ${user}
    kubectl --kubeconfig=${kubeconfig} config set-context ${user} \
        --cluster=${cluster} \
        --user=${user} \
        --namespace=${user}
    kubectl --kubeconfig=${kubeconfig} config use-context ${user}
    
    # Enable user to use their namespace
    kubectl create rolebinding ${user}-admin --namespace=${user} --clusterrole=admin --user=${user}

    # Enable token to have API access
    kubectl create rolebinding default-access-rest --namespace=${user} --clusterrole=admin --serviceaccount=${user}:default

    echo "Kubeconfig ready: ${kubeconfig}"
}


if [ $# -lt 1 ] ; then
    echo "Provide a user"
    exit 1
fi

user=$1
cafile=/tmp/cacert.$$

# Use the current context cluster address and CA Cert data
current_context=$(kubectl config view --raw -o jsonpath="{.current-context}")
cluster=$(kubectl config view --raw -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.cluster}")
address=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$cluster\")].cluster.server}")
cacert_data=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$cluster\")].cluster.certificate-authority-data}")
if [ -z ${cacert_data} ] ; then
    echo "No cert data found"
    exit 1
elif [ ! -f ${cacert_data} ] ; then
    echo ${cacert_data} | base64 -d > $cafile
#    delete_cafile=$cafile
else
    cafile=$cacert_data
fi

osd::createUserKubeconfig ${user}
#if [ -f $delete_cafile ] ; then
#    rm -f $delete_cafile > /dev/null 2>&1
#fi
