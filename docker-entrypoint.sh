#!/bin/bash
set -eo pipefail

# Logging function
# log [level] [msg] [msg]
log() {
    local log_level="${1}"
    shift
    if [ "${log_level}" == "info" ]; then
        echo -e "${*}"
    else
        echo -e "${*}" | sed "s/^/::${log_level}:: /g"
    fi
}

if [ -n "${INPUT_DEBUG}" ] || [ -n "${DEBUG}" ] || [ -n "${RUNNER_DEBUG}" ]; then
    IS_DEBUG=1
fi
IS_KUBECTL_ACTION_BASE=1
# We support every input parameter as an env var
CONFIG="${INPUT_CONFIG:-${CONFIG}}"
EKS_CLUSTER="${INPUT_EKS_CLUSTER:-${EKS_CLUSTER}}"
EKS_ROLE_ARN="${INPUT_EKS_ROLE_ARN:-${EKS_ROLE_ARN}}"
CONTEXT="${INPUT_CONTEXT:-${CONTEXT}}"

# Prepare kubeconfig
if [ -n "${CONFIG}" ]; then
    log info "Writing kube config."
    if [[ "${CONFIG}" =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)?$ ]]; then
        log debug "Assuming provided kube config is encoded in base64."
        echo "${CONFIG}" | base64 -d > "${KUBECONFIG}"
    else
        log debug "Assuming provided kube config is in plain text."
        echo "${CONFIG}" > "${KUBECONFIG}"
        
    fi
elif [ -n "${EKS_CLUSTER}" ]; then
    log info "Getting kube config for cluster ${EKS_CLUSTER}"
    if [ -n "${EKS_CLUSTER}" ]; then
        log debug "$(aws eks update-kubeconfig --name "${EKS_CLUSTER}" --role-arn "${EKS_CLUSTER}")"
    else
        log debug "$(aws eks update-kubeconfig --name "${EKS_CLUSTER}")"
    fi
else
    echo "::error:: Either config or eks_cluster must be specified."
    exit 2
fi

if [ -n "${CONTEXT}" ]; then
    log info "Setting kubectl context to ${CONTEXT}"
    kubectl config use-context "${CONTEXT}"
fi

current_context=$(kubectl config current-context)
log debug "Current kubectl context: ${current_context}"

if [ "$(ls -A /usr/local/bin/docker-entrypoint.d/)" ]; then
    for file in /usr/local/bin/docker-entrypoint.d/*; do
        # shellcheck source=/dev/null
        source ${file}
    done
fi
