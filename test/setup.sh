#!/bin/bash

# setting up colors
BLU='\033[0;104m'
YLW='\033[0;33m'
GRN='\033[0;32m'
RED='\033[0;31m'
NOC='\033[0m' # No Color

echo_info(){
    printf "\n${BLU}%s${NOC}\n" "$1"
}
echo_step(){
    printf "\n${BLU}>>>>>>> %s${NOC}\n" "$1"
}
echo_step_completed(){
    printf "${GRN} [✔] %s${NOC}\n" "$1"
}
echo_fatal(){
    printf "\n${RED}%s${NOC}\n" "$1"
    exit -1
}

SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )
CROSSPLANE_NAMESPACE="upbound-system"
DATADOG_NAMESPACE="monitoring"
KIND_CLUSTER_NAME="local-dev"

if [[ ${DATADOG_API_KEY} == "" ]]; then
    echo_fatal "Please set DATADOG_API_KEY in your environment"
fi

if [[ ${DATADOG_APP_KEY} == "" ]]; then
    export DATADOG_APP_KEY=${DATADOG_API_KEY}
fi

function check_if_exists_or_exit() {
    APP=$(which $1)
    if [[ "$APP" == "" ]]; then
	echo_fatal "$1 required. Aborting."
 	exit -1
    else
 	echo_step_completed "$1 exists"
    fi
}

echo_info "Checking for Applications"
check_if_exists_or_exit "kind"
check_if_exists_or_exit "kubectl"
check_if_exists_or_exit "docker"

echo_info "Building and Loading Datadog Agent with Upbound integration"
CWD=$(pwd)
cd ${SCRIPT_DIR}/../.up/config/datadog
docker build -t datadog-upbound_uxp:v1.0.0 .
echo_step_completed "Datadog Image Built"
cd ${CWD}
kind load docker-image datadog-upbound_uxp:v1.0.0 --name ${KIND_CLUSTER_NAME}
echo_step_completed "Loaded Docker image"

echo_info "Building and Loading Datadog XMetrics Agent with Upbound integration"
CWD=$(pwd)
cd ${SCRIPT_DIR}/../.up/config/datadog-xm
docker build -t datadog-upbound_xmetrics:v1.0.0 .
echo_step_completed "Datadog XMetrics Image Built"
cd ${CWD}
kind load docker-image datadog-upbound_xmetrics:v1.0.0 --name ${KIND_CLUSTER_NAME}
echo_step_completed "Loaded Docker XMetrics image"

echo_info "Waiting for Crossplane Pod readiness"
kubectl wait -n ${CROSSPLANE_NAMESPACE} pods --all --for condition=Ready 2>/dev/null
echo_step_completed "Universal Crossplane is ready"

CRDS_NOT_READY=true
echo_info "Waiting for CRDs to be available"
while [[ "$CRDS_NOT_READY" == "true" ]]; do
    sleep 7
    echo_step "Waiting for CRDs. This may take a moment"
    PROVIDERS=$(kubectl get crds 2>/dev/null|grep providers.pkg.crossplane.io)
    if [[ "$PROVIDERS" != "" ]]; then
        CRDS_NOT_READY=false
    fi
done
echo_step_completed "CRDs are available"

echo_info "Waiting for provider readiness ... this will take a moment"
kubectl wait provider.pkg --all --for condition=Healthy --timeout=15m 2>/dev/null
NUM_CRDS=$(kubectl get crds|wc -l)
echo_step_completed "Installed providers using ${NUM_CRDS} CRDs"

echo_info "Installing .up/config/provider/config-datadog"
kubectl apply -f ${SCRIPT_DIR}/../.up/config/provider/config-datadog.yaml
echo_step_completed "Installed .up/config/provider/config-datadog"

echo_info "Adding provider-kubernetes Service Account permissions"
SA=$(kubectl -n ${CROSSPLANE_NAMESPACE} get sa -o name|grep provider-kubernetes | sed -e "s|serviceaccount\/|${CROSSPLANE_NAMESPACE}:|g")
kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
echo_step_completed "Added provider-kubernetes Service Account permissions"

echo_info "Adding provider-helm Service Account permissions"
SA=$(kubectl -n ${CROSSPLANE_NAMESPACE} get sa -o name|grep provider-helm | sed -e "s|serviceaccount\/|${CROSSPLANE_NAMESPACE}:|g")
kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
echo_step_completed "Added provider-helm Service Account permissions"

echo_info "Installing definition"
kubectl apply -f ${SCRIPT_DIR}/../package/datadog/definition.yaml
echo_step_completed "Installed definition"

echo_info "Installing composition"
kubectl apply -f ${SCRIPT_DIR}/../package/datadog/composition.yaml
echo_step_completed "Installed composition"

echo_info "Creating datadog-creds"
kubectl create secret generic datadog-creds \
    --namespace ${CROSSPLANE_NAMESPACE} \
    --from-literal api-key=${DATADOG_API_KEY} \
    --from-literal app-key=${DATADOG_APP_KEY}
echo_step_completed "Created datadog-creds"
