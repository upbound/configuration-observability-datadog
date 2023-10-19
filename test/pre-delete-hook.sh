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

echo_info "Waiting for Kubernetes resource readiness"
kubectl wait object.kubernetes.crossplane.io --all --for condition=Ready --timeout=15m 2>/dev/null
echo_step_completed "Kubernetes resources are ready"

sleep 3
kubectl get managed

echo_info "Waiting for Datadog Pod readiness"
kubectl wait -n monitoring pods --all --for condition=Ready 2>/dev/null
echo_step_completed "Datadog pods are ready"

DATADOG_AGENT_POD=""
while [[ "$DATADOG_AGENT_POD" == "" ]]; do
    sleep 3
    DATADOG_AGENT_POD=$(kubectl -n ${DATADOG_NAMESPACE} get pods|\
	grep datadog|\
	grep -v cluster|awk '{print $1}')
done
sleep 3

echo_info "Running Datadog agent check for upbound_uxp integration"
kubectl -n ${DATADOG_NAMESPACE} exec ${DATADOG_AGENT_POD} -- agent check upbound_uxp 2>/dev/null|tail -21
echo_step_completed "Ran Datadog agent check for upbound_uxp integration"

echo_step_completed "Pre-delete hook complete"
