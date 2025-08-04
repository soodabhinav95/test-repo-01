#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     Kubernetes Complete Toolkit                             ║
# ║          One-stop solution for all Kubernetes operations                    ║
# ║                   with fzf, yazi, and bat integration                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# Source this file: source /path/to/k8s-toolkit.sh
# Or add to your shell profile: echo 'source ~/.k8s-toolkit.sh' >> ~/.bashrc

# Version and metadata
K8S_TOOLKIT_VERSION="2.0.0"
K8S_TOOLKIT_AUTHOR="Kubernetes Community"

# Colors for output
readonly K8S_RED='\033[0;31m'
readonly K8S_GREEN='\033[0;32m'
readonly K8S_YELLOW='\033[0;33m'
readonly K8S_BLUE='\033[0;34m'
readonly K8S_PURPLE='\033[0;35m'
readonly K8S_CYAN='\033[0;36m'
readonly K8S_WHITE='\033[0;37m'
readonly K8S_BOLD='\033[1m'
readonly K8S_NC='\033[0m' # No Color

# Global configuration
K8S_DEFAULT_NAMESPACE=""
K8S_LAST_CONTEXT=""
K8S_TOOLKIT_DEBUG=false

# Utility functions
k8s_log() {
    local level="$1"
    shift
    case "$level" in
        "info") echo -e "${K8S_BLUE}[INFO]${K8S_NC} $*" ;;
        "warn") echo -e "${K8S_YELLOW}[WARN]${K8S_NC} $*" ;;
        "error") echo -e "${K8S_RED}[ERROR]${K8S_NC} $*" ;;
        "success") echo -e "${K8S_GREEN}[SUCCESS]${K8S_NC} $*" ;;
        "debug") [[ "$K8S_TOOLKIT_DEBUG" == "true" ]] && echo -e "${K8S_PURPLE}[DEBUG]${K8S_NC} $*" ;;
    esac
}

# Check if kubectl is available and cluster is reachable
k8s_check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        k8s_log error "kubectl is not installed or not in PATH"
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        k8s_log error "Cannot connect to Kubernetes cluster. Check your context and connectivity."
        return 1
    fi
    
    return 0
}

# Check if required tools are available
k8s_check_tools() {
    local missing_tools=()
    
    for tool in fzf bat; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        k8s_log warn "Missing optional tools: ${missing_tools[*]}"
        k8s_log info "Install them for enhanced experience: sudo apt install ${missing_tools[*]}"
    fi
}

# Parse namespace from arguments
k8s_parse_namespace() {
    local namespace=""
    local args=("$@")
    
    # Look for -n or --namespace flags
    for i in "${!args[@]}"; do
        if [[ "${args[i]}" == "-n" ]] || [[ "${args[i]}" == "--namespace" ]]; then
            if [[ -n "${args[i+1]}" ]]; then
                namespace="${args[i+1]}"
                # Remove the flag and value from args
                unset 'args[i]' 'args[i+1]'
                break
            fi
        fi
    done
    
    # Use current context namespace if none specified
    if [[ -z "$namespace" ]] && [[ -n "$K8S_DEFAULT_NAMESPACE" ]]; then
        namespace="$K8S_DEFAULT_NAMESPACE"
    fi
    
    # Return namespace and remaining args
    echo "$namespace"
    echo "${args[@]}"
}

# Get current context and namespace
k8s_get_current_context() {
    local context=$(kubectl config current-context 2>/dev/null || echo "none")
    local namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
    echo "$context:$namespace"
}

# Set default namespace for toolkit
k8s_set_default_namespace() {
    local namespace="$1"
    if [[ -z "$namespace" ]]; then
        k8s_log error "Please provide a namespace"
        return 1
    fi
    
    K8S_DEFAULT_NAMESPACE="$namespace"
    k8s_log success "Default namespace set to: $namespace"
}

# ════════════════════════════════════════════════════════════════════════════════
# CORE RESOURCE MANAGEMENT FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

# Interactive pod operations
k8s_pods() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Working in namespace: $namespace"
    fi
    
    # Get pods with enhanced information
    local pod_list=$(kubectl get pods $ns_flag -o wide --no-headers 2>/dev/null)
    if [[ -z "$pod_list" ]]; then
        k8s_log warn "No pods found in namespace: ${namespace:-default}"
        return 0
    fi
    
    # Use fzf for selection with preview
    local selected_pod=""
    if command -v fzf &> /dev/null; then
        selected_pod=$(echo "$pod_list" | \
            fzf --header="Select a pod (namespace: ${namespace:-default})" \
                --preview="kubectl describe pod {1} $ns_flag 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --bind="ctrl-r:reload(kubectl get pods $ns_flag -o wide --no-headers)" \
                --height=80% | \
            awk '{print $1}')
    else
        echo "$pod_list"
        echo -e "\n${K8S_CYAN}Enter pod name:${K8S_NC}"
        read -r selected_pod
    fi
    
    if [[ -z "$selected_pod" ]]; then
        k8s_log info "No pod selected"
        return 0
    fi
    
    k8s_log success "Selected pod: $selected_pod"
    
    # Action selection
    local actions=(
        "logs:View recent logs"
        "logs-follow:Follow logs in real-time"
        "logs-previous:View previous container logs"
        "describe:Describe pod details"
        "exec-bash:Execute bash shell"
        "exec-sh:Execute sh shell"
        "exec-custom:Execute custom command"
        "port-forward:Port forward to pod"
        "copy-from:Copy file from pod"
        "copy-to:Copy file to pod"
        "edit:Edit pod YAML"
        "delete:Delete pod"
        "restart:Restart pod (delete and let controller recreate)"
        "debug:Create debug container"
        "events:Show pod events"
        "yaml:Export pod YAML"
    )
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="What would you like to do with $selected_pod?" \
                --preview="echo {2}" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "\n${K8S_CYAN}Available actions:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    # Handle multi-container pods
    local containers=$(kubectl get pod "$selected_pod" $ns_flag -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
    local container_flag=""
    
    if [[ $(echo "$containers" | wc -w) -gt 1 ]] && [[ "$action" =~ ^(logs|logs-follow|logs-previous|exec-bash|exec-sh|exec-custom)$ ]]; then
        k8s_log info "Multi-container pod detected. Containers: $containers"
        local selected_container=""
        if command -v fzf &> /dev/null; then
            selected_container=$(echo "$containers" | tr ' ' '\n' | \
                fzf --header="Select container")
        else
            echo -e "${K8S_CYAN}Select container:${K8S_NC}"
            select selected_container in $containers; do
                break
            done
        fi
        [[ -n "$selected_container" ]] && container_flag="-c $selected_container"
    fi
    
    # Execute selected action
    case "$action" in
        "logs")
            local log_output=$(kubectl logs "$selected_pod" $ns_flag $container_flag --tail=100 2>/dev/null)
            if command -v bat &> /dev/null; then
                echo "$log_output" | bat --language=log --style=plain --paging=always
            else
                echo "$log_output" | less
            fi
            ;;
        "logs-follow")
            kubectl logs -f "$selected_pod" $ns_flag $container_flag
            ;;
        "logs-previous")
            local prev_logs=$(kubectl logs "$selected_pod" $ns_flag $container_flag --previous 2>/dev/null)
            if command -v bat &> /dev/null; then
                echo "$prev_logs" | bat --language=log --style=plain --paging=always
            else
                echo "$prev_logs" | less
            fi
            ;;
        "describe")
            local describe_output=$(kubectl describe pod "$selected_pod" $ns_flag 2>/dev/null)
            if command -v bat &> /dev/null; then
                echo "$describe_output" | bat --language=yaml --style=plain --paging=always
            else
                echo "$describe_output" | less
            fi
            ;;
        "exec-bash")
            kubectl exec -it "$selected_pod" $ns_flag $container_flag -- bash
            ;;
        "exec-sh")
            kubectl exec -it "$selected_pod" $ns_flag $container_flag -- sh
            ;;
        "exec-custom")
            echo -e "${K8S_CYAN}Enter command to execute:${K8S_NC}"
            read -r custom_cmd
            kubectl exec -it "$selected_pod" $ns_flag $container_flag -- $custom_cmd
            ;;
        "port-forward")
            echo -e "${K8S_CYAN}Enter local:remote port (e.g., 8080:80):${K8S_NC}"
            read -r ports
            k8s_log info "Port forwarding $ports for $selected_pod"
            kubectl port-forward "$selected_pod" $ns_flag $ports
            ;;
        "copy-from")
            echo -e "${K8S_CYAN}Enter pod path to copy from:${K8S_NC}"
            read -r pod_path
            echo -e "${K8S_CYAN}Enter local destination:${K8S_NC}"
            read -r local_path
            kubectl cp "$selected_pod:$pod_path" "$local_path" $ns_flag $container_flag
            k8s_log success "Copied from $selected_pod:$pod_path to $local_path"
            ;;
        "copy-to")
            echo -e "${K8S_CYAN}Enter local file to copy:${K8S_NC}"
            read -r local_path
            echo -e "${K8S_CYAN}Enter pod destination path:${K8S_NC}"
            read -r pod_path
            kubectl cp "$local_path" "$selected_pod:$pod_path" $ns_flag $container_flag
            k8s_log success "Copied $local_path to $selected_pod:$pod_path"
            ;;
        "edit")
            kubectl edit pod "$selected_pod" $ns_flag
            ;;
        "delete")
            echo -e "${K8S_YELLOW}Are you sure you want to delete pod $selected_pod? (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl delete pod "$selected_pod" $ns_flag
                k8s_log success "Pod $selected_pod deleted"
            fi
            ;;
        "restart")
            echo -e "${K8S_YELLOW}Are you sure you want to restart pod $selected_pod? (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl delete pod "$selected_pod" $ns_flag
                k8s_log success "Pod $selected_pod restarted (deleted for recreation)"
            fi
            ;;
        "debug")
            echo -e "${K8S_CYAN}Enter debug image (default: busybox):${K8S_NC}"
            read -r debug_image
            debug_image=${debug_image:-busybox}
            kubectl debug "$selected_pod" $ns_flag --image="$debug_image" --share-processes --copy-to="${selected_pod}-debug"
            ;;
        "events")
            kubectl get events $ns_flag --field-selector involvedObject.name="$selected_pod" --sort-by=.metadata.creationTimestamp
            ;;
        "yaml")
            local yaml_output=$(kubectl get pod "$selected_pod" $ns_flag -o yaml)
            if command -v bat &> /dev/null; then
                echo "$yaml_output" | bat --language=yaml --paging=always
            else
                echo "$yaml_output" | less
            fi
            ;;
    esac
}

# Interactive service operations
k8s_services() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Working in namespace: $namespace"
    fi
    
    local service_list=$(kubectl get services $ns_flag -o wide --no-headers 2>/dev/null)
    if [[ -z "$service_list" ]]; then
        k8s_log warn "No services found in namespace: ${namespace:-default}"
        return 0
    fi
    
    local selected_service=""
    if command -v fzf &> /dev/null; then
        selected_service=$(echo "$service_list" | \
            fzf --header="Select a service (namespace: ${namespace:-default})" \
                --preview="kubectl describe service {1} $ns_flag 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --height=80% | \
            awk '{print $1}')
    else
        echo "$service_list"
        echo -e "\n${K8S_CYAN}Enter service name:${K8S_NC}"
        read -r selected_service
    fi
    
    [[ -z "$selected_service" ]] && return 0
    
    k8s_log success "Selected service: $selected_service"
    
    local actions=(
        "describe:Describe service details"
        "endpoints:Show service endpoints"
        "port-forward:Port forward to service"
        "edit:Edit service YAML"
        "delete:Delete service"
        "yaml:Export service YAML"
        "test-connectivity:Test service connectivity"
        "pods:Show pods backing this service"
    )
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="What would you like to do with $selected_service?" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "\n${K8S_CYAN}Available actions:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "describe")
            local describe_output=$(kubectl describe service "$selected_service" $ns_flag)
            if command -v bat &> /dev/null; then
                echo "$describe_output" | bat --language=yaml --style=plain --paging=always
            else
                echo "$describe_output" | less
            fi
            ;;
        "endpoints")
            kubectl get endpoints "$selected_service" $ns_flag -o yaml | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --paging=always
                else
                    less
                fi
            ;;
        "port-forward")
            echo -e "${K8S_CYAN}Enter local:remote port (e.g., 8080:80):${K8S_NC}"
            read -r ports
            k8s_log info "Port forwarding $ports for service $selected_service"
            kubectl port-forward "service/$selected_service" $ns_flag $ports
            ;;
        "edit")
            kubectl edit service "$selected_service" $ns_flag
            ;;
        "delete")
            echo -e "${K8S_YELLOW}Are you sure you want to delete service $selected_service? (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl delete service "$selected_service" $ns_flag
                k8s_log success "Service $selected_service deleted"
            fi
            ;;
        "yaml")
            kubectl get service "$selected_service" $ns_flag -o yaml | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --paging=always
                else
                    less
                fi
            ;;
        "test-connectivity")
            local service_ip=$(kubectl get service "$selected_service" $ns_flag -o jsonpath='{.spec.clusterIP}')
            local service_port=$(kubectl get service "$selected_service" $ns_flag -o jsonpath='{.spec.ports[0].port}')
            k8s_log info "Testing connectivity to $service_ip:$service_port"
            kubectl run test-connectivity-$RANDOM --rm -i --tty --image=busybox --restart=Never -- nc -zv "$service_ip" "$service_port"
            ;;
        "pods")
            local selector=$(kubectl get service "$selected_service" $ns_flag -o jsonpath='{.spec.selector}' | tr -d '{}' | tr ',' '\n')
            if [[ -n "$selector" ]]; then
                k8s_log info "Pods backing service $selected_service:"
                kubectl get pods $ns_flag -l "$selector"
            else
                k8s_log warn "Service $selected_service has no selector"
            fi
            ;;
    esac
}

# Interactive deployment operations
k8s_deployments() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Working in namespace: $namespace"
    fi
    
    local deployment_list=$(kubectl get deployments $ns_flag -o wide --no-headers 2>/dev/null)
    if [[ -z "$deployment_list" ]]; then
        k8s_log warn "No deployments found in namespace: ${namespace:-default}"
        return 0
    fi
    
    local selected_deployment=""
    if command -v fzf &> /dev/null; then
        selected_deployment=$(echo "$deployment_list" | \
            fzf --header="Select a deployment (namespace: ${namespace:-default})" \
                --preview="kubectl describe deployment {1} $ns_flag 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --height=80% | \
            awk '{print $1}')
    else
        echo "$deployment_list"
        echo -e "\n${K8S_CYAN}Enter deployment name:${K8S_NC}"
        read -r selected_deployment
    fi
    
    [[ -z "$selected_deployment" ]] && return 0
    
    k8s_log success "Selected deployment: $selected_deployment"
    
    local actions=(
        "describe:Describe deployment details"
        "scale:Scale deployment replicas"
        "restart:Restart deployment"
        "rollout-status:Check rollout status"
        "rollout-history:Show rollout history"
        "rollout-undo:Undo last rollout"
        "rollout-pause:Pause rollout"
        "rollout-resume:Resume rollout"
        "edit:Edit deployment YAML"
        "delete:Delete deployment"
        "yaml:Export deployment YAML"
        "pods:Show deployment pods"
        "events:Show deployment events"
        "set-image:Update container image"
        "set-env:Set environment variable"
    )
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="What would you like to do with $selected_deployment?" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "\n${K8S_CYAN}Available actions:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "describe")
            kubectl describe deployment "$selected_deployment" $ns_flag | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --style=plain --paging=always
                else
                    less
                fi
            ;;
        "scale")
            local current_replicas=$(kubectl get deployment "$selected_deployment" $ns_flag -o jsonpath='{.spec.replicas}')
            echo -e "${K8S_CYAN}Current replicas: $current_replicas${K8S_NC}"
            echo -e "${K8S_CYAN}Enter new replica count:${K8S_NC}"
            read -r new_replicas
            if [[ "$new_replicas" =~ ^[0-9]+$ ]]; then
                kubectl scale deployment "$selected_deployment" $ns_flag --replicas="$new_replicas"
                k8s_log success "Scaled $selected_deployment to $new_replicas replicas"
            else
                k8s_log error "Invalid replica count: $new_replicas"
            fi
            ;;
        "restart")
            kubectl rollout restart deployment "$selected_deployment" $ns_flag
            k8s_log success "Deployment $selected_deployment restart initiated"
            ;;
        "rollout-status")
            kubectl rollout status deployment "$selected_deployment" $ns_flag
            ;;
        "rollout-history")
            kubectl rollout history deployment "$selected_deployment" $ns_flag
            ;;
        "rollout-undo")
            echo -e "${K8S_YELLOW}Are you sure you want to undo the last rollout for $selected_deployment? (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl rollout undo deployment "$selected_deployment" $ns_flag
                k8s_log success "Rollout undone for $selected_deployment"
            fi
            ;;
        "rollout-pause")
            kubectl rollout pause deployment "$selected_deployment" $ns_flag
            k8s_log success "Rollout paused for $selected_deployment"
            ;;
        "rollout-resume")
            kubectl rollout resume deployment "$selected_deployment" $ns_flag
            k8s_log success "Rollout resumed for $selected_deployment"
            ;;
        "edit")
            kubectl edit deployment "$selected_deployment" $ns_flag
            ;;
        "delete")
            echo -e "${K8S_YELLOW}Are you sure you want to delete deployment $selected_deployment? This will also delete all pods! (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl delete deployment "$selected_deployment" $ns_flag
                k8s_log success "Deployment $selected_deployment deleted"
            fi
            ;;
        "yaml")
            kubectl get deployment "$selected_deployment" $ns_flag -o yaml | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --paging=always
                else
                    less
                fi
            ;;
        "pods")
            kubectl get pods $ns_flag -l "app=$selected_deployment" -o wide
            ;;
        "events")
            kubectl get events $ns_flag --field-selector involvedObject.name="$selected_deployment" --sort-by=.metadata.creationTimestamp
            ;;
        "set-image")
            local containers=$(kubectl get deployment "$selected_deployment" $ns_flag -o jsonpath='{.spec.template.spec.containers[*].name}')
            echo -e "${K8S_CYAN}Available containers: $containers${K8S_NC}"
            echo -e "${K8S_CYAN}Enter container name:${K8S_NC}"
            read -r container_name
            echo -e "${K8S_CYAN}Enter new image:${K8S_NC}"
            read -r new_image
            kubectl set image deployment/"$selected_deployment" "$container_name=$new_image" $ns_flag
            k8s_log success "Image updated for $container_name to $new_image"
            ;;
        "set-env")
            echo -e "${K8S_CYAN}Enter environment variable (KEY=VALUE):${K8S_NC}"
            read -r env_var
            kubectl set env deployment/"$selected_deployment" "$env_var" $ns_flag
            k8s_log success "Environment variable set: $env_var"
            ;;
    esac
}

# Interactive namespace operations
k8s_namespaces() {
    k8s_check_kubectl || return 1
    
    local namespace_list=$(kubectl get namespaces --no-headers 2>/dev/null)
    if [[ -z "$namespace_list" ]]; then
        k8s_log warn "No namespaces found"
        return 0
    fi
    
    local selected_namespace=""
    if command -v fzf &> /dev/null; then
        selected_namespace=$(echo "$namespace_list" | \
            fzf --header="Select a namespace" \
                --preview="kubectl get all -n {1} 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --height=80% | \
            awk '{print $1}')
    else
        echo "$namespace_list"
        echo -e "\n${K8S_CYAN}Enter namespace name:${K8S_NC}"
        read -r selected_namespace
    fi
    
    [[ -z "$selected_namespace" ]] && return 0
    
    k8s_log success "Selected namespace: $selected_namespace"
    
    local actions=(
        "set-default:Set as default namespace for toolkit"
        "set-context:Set current context to this namespace"
        "overview:Show namespace overview"
        "pods:List all pods"
        "services:List all services"
        "deployments:List all deployments"
        "configmaps:List all configmaps"
        "secrets:List all secrets"
        "events:Show namespace events"
        "describe:Describe namespace"
        "yaml:Export namespace YAML"
        "delete:Delete namespace"
        "resource-quota:Show resource quotas"
        "network-policies:Show network policies"
    )
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="What would you like to do with $selected_namespace?" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "\n${K8S_CYAN}Available actions:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "set-default")
            k8s_set_default_namespace "$selected_namespace"
            ;;
        "set-context")
            kubectl config set-context --current --namespace="$selected_namespace"
            k8s_log success "Context set to namespace: $selected_namespace"
            ;;
        "overview")
            kubectl get all -n "$selected_namespace" | \
                if command -v bat &> /dev/null; then
                    bat --style=plain --paging=always
                else
                    less
                fi
            ;;
        "pods")
            kubectl get pods -n "$selected_namespace" -o wide
            ;;
        "services")
            kubectl get services -n "$selected_namespace" -o wide
            ;;
        "deployments")
            kubectl get deployments -n "$selected_namespace" -o wide
            ;;
        "configmaps")
            kubectl get configmaps -n "$selected_namespace"
            ;;
        "secrets")
            kubectl get secrets -n "$selected_namespace"
            ;;
        "events")
            kubectl get events -n "$selected_namespace" --sort-by=.metadata.creationTimestamp
            ;;
        "describe")
            kubectl describe namespace "$selected_namespace" | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --style=plain --paging=always
                else
                    less
                fi
            ;;
        "yaml")
            kubectl get namespace "$selected_namespace" -o yaml | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --paging=always
                else
                    less
                fi
            ;;
        "delete")
            echo -e "${K8S_RED}WARNING: This will delete the entire namespace and ALL resources in it!${K8S_NC}"
            echo -e "${K8S_YELLOW}Are you sure you want to delete namespace $selected_namespace? (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl delete namespace "$selected_namespace"
                k8s_log success "Namespace $selected_namespace deleted"
            fi
            ;;
        "resource-quota")
            kubectl get resourcequota -n "$selected_namespace" -o wide
            ;;
        "network-policies")
            kubectl get networkpolicy -n "$selected_namespace" -o wide
            ;;
    esac
}

# ════════════════════════════════════════════════════════════════════════════════
# CONFIGURATION MANAGEMENT FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

# Interactive ConfigMap and Secret management
k8s_configs() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Working in namespace: $namespace"
    fi
    
    # Select resource type
    local resource_types=("configmap:Configuration Maps" "secret:Secrets")
    local resource_type=""
    
    if command -v fzf &> /dev/null; then
        resource_type=$(printf '%s\n' "${resource_types[@]}" | \
            fzf --header="Select resource type" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "${K8S_CYAN}Select resource type:${K8S_NC}"
        select resource_type in configmap secret; do
            break
        done
    fi
    
    [[ -z "$resource_type" ]] && return 0
    
    local resource_list=$(kubectl get "$resource_type" $ns_flag --no-headers 2>/dev/null)
    if [[ -z "$resource_list" ]]; then
        k8s_log warn "No ${resource_type}s found in namespace: ${namespace:-default}"
        return 0
    fi
    
    local selected_resource=""
    if command -v fzf &> /dev/null; then
        selected_resource=$(echo "$resource_list" | \
            fzf --header="Select a $resource_type" \
                --preview="kubectl describe $resource_type {1} $ns_flag 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --height=80% | \
            awk '{print $1}')
    else
        echo "$resource_list"
        echo -e "\n${K8S_CYAN}Enter $resource_type name:${K8S_NC}"
        read -r selected_resource
    fi
    
    [[ -z "$selected_resource" ]] && return 0
    
    k8s_log success "Selected $resource_type: $selected_resource"
    
    local actions=(
        "view:View resource content"
        "describe:Describe resource"
        "edit:Edit resource"
        "delete:Delete resource"
        "yaml:Export as YAML"
        "json:Export as JSON"
        "backup:Create backup file"
        "decode:Decode secret values (secrets only)"
    )
    
    # Remove decode option for configmaps
    if [[ "$resource_type" != "secret" ]]; then
        actions=("${actions[@]/decode:*/}")
    fi
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="What would you like to do with $selected_resource?" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "\n${K8S_CYAN}Available actions:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "view")
            kubectl get "$resource_type" "$selected_resource" $ns_flag -o yaml | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --paging=always
                else
                    less
                fi
            ;;
        "describe")
            kubectl describe "$resource_type" "$selected_resource" $ns_flag | \
                if command -v bat &> /dev/null; then
                    bat --language=yaml --style=plain --paging=always
                else
                    less
                fi
            ;;
        "edit")
            kubectl edit "$resource_type" "$selected_resource" $ns_flag
            ;;
        "delete")
            echo -e "${K8S_YELLOW}Are you sure you want to delete $resource_type $selected_resource? (y/N)${K8S_NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                kubectl delete "$resource_type" "$selected_resource" $ns_flag
                k8s_log success "$resource_type $selected_resource deleted"
            fi
            ;;
        "yaml")
            local filename="${selected_resource}-${resource_type}-$(date +%Y%m%d-%H%M%S).yaml"
            kubectl get "$resource_type" "$selected_resource" $ns_flag -o yaml > "$filename"
            k8s_log success "Exported to: $filename"
            ;;
        "json")
            local filename="${selected_resource}-${resource_type}-$(date +%Y%m%d-%H%M%S).json"
            kubectl get "$resource_type" "$selected_resource" $ns_flag -o json > "$filename"
            k8s_log success "Exported to: $filename"
            ;;
        "backup")
            local backup_dir="k8s-backups-$(date +%Y%m%d)"
            mkdir -p "$backup_dir"
            local filename="$backup_dir/${selected_resource}-${resource_type}.yaml"
            kubectl get "$resource_type" "$selected_resource" $ns_flag -o yaml > "$filename"
            k8s_log success "Backup created: $filename"
            ;;
        "decode")
            if [[ "$resource_type" == "secret" ]]; then
                kubectl get secret "$selected_resource" $ns_flag -o json | \
                    jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' | \
                    if command -v bat &> /dev/null; then
                        bat --language=yaml --style=plain --paging=always
                    else
                        less
                    fi
            fi
            ;;
    esac
}

# Browse all resources with file manager
k8s_browse() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Working in namespace: $namespace"
    fi
    
    # Create temporary directory for exports
    local temp_dir=$(mktemp -d -t k8s-browse-XXXXXX)
    k8s_log info "Exporting resources to: $temp_dir"
    
    # Create subdirectories
    local resource_types=("pods" "services" "deployments" "configmaps" "secrets" "ingresses" "jobs" "cronjobs")
    for resource_type in "${resource_types[@]}"; do
        mkdir -p "$temp_dir/$resource_type"
    done
    
    # Export resources in parallel
    {
        kubectl get pods $ns_flag -o name 2>/dev/null | while IFS= read -r resource; do
            name=$(basename "$resource")
            kubectl get pod "$name" $ns_flag -o yaml > "$temp_dir/pods/${name}.yaml" 2>/dev/null &
        done
        
        kubectl get services $ns_flag -o name 2>/dev/null | while IFS= read -r resource; do
            name=$(basename "$resource")
            kubectl get service "$name" $ns_flag -o yaml > "$temp_dir/services/${name}.yaml" 2>/dev/null &
        done
        
        kubectl get deployments $ns_flag -o name 2>/dev/null | while IFS= read -r resource; do
            name=$(basename "$resource")
            kubectl get deployment "$name" $ns_flag -o yaml > "$temp_dir/deployments/${name}.yaml" 2>/dev/null &
        done
        
        kubectl get configmaps $ns_flag -o name 2>/dev/null | while IFS= read -r resource; do
            name=$(basename "$resource")
            kubectl get configmap "$name" $ns_flag -o yaml > "$temp_dir/configmaps/${name}.yaml" 2>/dev/null &
        done
        
        kubectl get secrets $ns_flag -o name 2>/dev/null | while IFS= read -r resource; do
            name=$(basename "$resource")
            kubectl get secret "$name" $ns_flag -o yaml > "$temp_dir/secrets/${name}.yaml" 2>/dev/null &
        done
        
        wait
    } &
    
    local export_pid=$!
    k8s_log info "Exporting resources in background (PID: $export_pid)..."
    wait $export_pid
    
    k8s_log success "Export completed"
    
    # Create a README file
    cat > "$temp_dir/README.md" << EOF
# Kubernetes Resources Export
Namespace: ${namespace:-default}
Export time: $(date)
Export directory: $temp_dir

## Directory Structure
- pods/ - Pod YAML files
- services/ - Service YAML files  
- deployments/ - Deployment YAML files
- configmaps/ - ConfigMap YAML files
- secrets/ - Secret YAML files
- ingresses/ - Ingress YAML files

## Usage
- Use yazi/ranger to browse files
- Use bat to view YAML files with syntax highlighting
- Files are exported in YAML format for easy reading
EOF
    
    # Open with file manager
    if command -v yazi &> /dev/null; then
        k8s_log info "Opening with yazi file manager..."
        yazi "$temp_dir"
    elif command -v ranger &> /dev/null; then
        k8s_log info "Opening with ranger file manager..."
        ranger "$temp_dir"
    else
        k8s_log info "No supported file manager found. Resources available at: $temp_dir"
        ls -la "$temp_dir"
        echo -e "\n${K8S_CYAN}Use 'bat' to view YAML files:${K8S_NC}"
        echo "bat $temp_dir/pods/*.yaml"
    fi
    
    # Cleanup prompt
    echo -e "\n${K8S_YELLOW}Clean up temporary directory? (y/N)${K8S_NC}"
    read -r cleanup
    if [[ "$cleanup" =~ ^[Yy]$ ]]; then
        rm -rf "$temp_dir"
        k8s_log success "Temporary directory cleaned up"
    else
        k8s_log info "Resources preserved at: $temp_dir"
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# MONITORING AND TROUBLESHOOTING FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

# Interactive log viewer
k8s_logs() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Working in namespace: $namespace"
    fi
    
    local pod_list=$(kubectl get pods $ns_flag --no-headers 2>/dev/null)
    if [[ -z "$pod_list" ]]; then
        k8s_log warn "No pods found in namespace: ${namespace:-default}"
        return 0
    fi
    
    local selected_pod=""
    if command -v fzf &> /dev/null; then
        selected_pod=$(echo "$pod_list" | \
            fzf --header="Select a pod for logs" \
                --preview="kubectl logs {1} $ns_flag --tail=20 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --height=80% | \
            awk '{print $1}')
    else
        echo "$pod_list"
        echo -e "\n${K8S_CYAN}Enter pod name:${K8S_NC}"
        read -r selected_pod
    fi
    
    [[ -z "$selected_pod" ]] && return 0
    
    k8s_log success "Selected pod: $selected_pod"
    
    # Handle multi-container pods
    local containers=$(kubectl get pod "$selected_pod" $ns_flag -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
    local container_flag=""
    
    if [[ $(echo "$containers" | wc -w) -gt 1 ]]; then
        k8s_log info "Multi-container pod. Containers: $containers"
        local selected_container=""
        if command -v fzf &> /dev/null; then
            selected_container=$(echo "$containers" | tr ' ' '\n' | \
                fzf --header="Select container")
        else
            echo -e "${K8S_CYAN}Select container:${K8S_NC}"
            select selected_container in $containers; do
                break
            done
        fi
        [[ -n "$selected_container" ]] && container_flag="-c $selected_container"
    fi
    
    local actions=(
        "tail:View recent logs (last 100 lines)"
        "follow:Follow logs in real-time"
        "all:View all logs"
        "previous:View previous container logs"
        "since:View logs since specific time"
        "save:Save logs to file"
        "search:Search in logs"
        "errors:Filter error lines only"
    )
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="Log viewing options for $selected_pod" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "\n${K8S_CYAN}Available actions:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "tail")
            kubectl logs "$selected_pod" $ns_flag $container_flag --tail=100 | \
                if command -v bat &> /dev/null; then
                    bat --language=log --style=plain --paging=always
                else
                    less
                fi
            ;;
        "follow")
            kubectl logs -f "$selected_pod" $ns_flag $container_flag
            ;;
        "all")
            kubectl logs "$selected_pod" $ns_flag $container_flag | \
                if command -v bat &> /dev/null; then
                    bat --language=log --style=plain --paging=always
                else
                    less
                fi
            ;;
        "previous")
            kubectl logs "$selected_pod" $ns_flag $container_flag --previous 2>/dev/null | \
                if command -v bat &> /dev/null; then
                    bat --language=log --style=plain --paging=always
                else
                    less
                fi
            ;;
        "since")
            echo -e "${K8S_CYAN}Enter time (e.g., 1h, 30m, 2006-01-02T15:04:05Z):${K8S_NC}"
            read -r since_time
            kubectl logs "$selected_pod" $ns_flag $container_flag --since="$since_time" | \
                if command -v bat &> /dev/null; then
                    bat --language=log --style=plain --paging=always
                else
                    less
                fi
            ;;
        "save")
            local filename="${selected_pod}-$(date +%Y%m%d-%H%M%S).log"
            kubectl logs "$selected_pod" $ns_flag $container_flag > "$filename"
            k8s_log success "Logs saved to: $filename"
            ;;
        "search")
            echo -e "${K8S_CYAN}Enter search pattern:${K8S_NC}"
            read -r search_pattern
            kubectl logs "$selected_pod" $ns_flag $container_flag | grep -i "$search_pattern" | \
                if command -v bat &> /dev/null; then
                    bat --language=log --style=plain --paging=always
                else
                    less
                fi
            ;;
        "errors")
            kubectl logs "$selected_pod" $ns_flag $container_flag | grep -iE "(error|fail|exception|panic|fatal)" | \
                if command -v bat &> /dev/null; then
                    bat --language=log --style=plain --paging=always
                else
                    less
                fi
            ;;
    esac
}

# Resource usage monitoring
k8s_top() {
    k8s_check_kubectl || return 1
    
    # Check if metrics server is available
    if ! kubectl top nodes &>/dev/null; then
        k8s_log warn "Metrics server not available. Cannot show resource usage."
        k8s_log info "Install metrics server: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
        return 1
    fi
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
    fi
    
    local resource_types=("nodes:Node resource usage" "pods:Pod resource usage")
    local resource_type=""
    
    if command -v fzf &> /dev/null; then
        resource_type=$(printf '%s\n' "${resource_types[@]}" | \
            fzf --header="Select resource type to monitor" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "${K8S_CYAN}Select resource type:${K8S_NC}"
        select resource_type in nodes pods; do
            break
        done
    fi
    
    [[ -z "$resource_type" ]] && return 0
    
    local actions=("once:Show current usage" "watch:Monitor continuously" "sort-cpu:Sort by CPU usage" "sort-memory:Sort by memory usage")
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="Monitoring options" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "${K8S_CYAN}Monitoring options:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "once")
            if [[ "$resource_type" == "nodes" ]]; then
                kubectl top nodes
            else
                kubectl top pods $ns_flag
            fi
            ;;
        "watch")
            if command -v watch &> /dev/null; then
                if [[ "$resource_type" == "nodes" ]]; then
                    watch -n 2 kubectl top nodes
                else
                    watch -n 2 kubectl top pods $ns_flag
                fi
            else
                k8s_log warn "watch command not available. Showing current usage:"
                if [[ "$resource_type" == "nodes" ]]; then
                    kubectl top nodes
                else
                    kubectl top pods $ns_flag
                fi
            fi
            ;;
        "sort-cpu")
            if [[ "$resource_type" == "nodes" ]]; then
                kubectl top nodes --sort-by=cpu
            else
                kubectl top pods $ns_flag --sort-by=cpu
            fi
            ;;
        "sort-memory")
            if [[ "$resource_type" == "nodes" ]]; then
                kubectl top nodes --sort-by=memory
            else
                kubectl top pods $ns_flag --sort-by=memory
            fi
            ;;
    esac
}

# ════════════════════════════════════════════════════════════════════════════════
# CONTEXT AND CLUSTER MANAGEMENT FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

# Context switching with enhanced features
k8s_context() {
    k8s_check_kubectl || return 1
    
    local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
    local contexts=$(kubectl config get-contexts -o name 2>/dev/null)
    
    if [[ -z "$contexts" ]]; then
        k8s_log warn "No contexts found"
        return 0
    fi
    
    k8s_log info "Current context: $current_context"
    
    local selected_context=""
    if command -v fzf &> /dev/null; then
        selected_context=$(echo "$contexts" | \
            fzf --header="Select a context (current: $current_context)" \
                --preview="kubectl config get-contexts {} 2>/dev/null" \
                --preview-window=right:60%:wrap \
                --height=60%)
    else
        echo "$contexts"
        echo -e "\n${K8S_CYAN}Enter context name:${K8S_NC}"
        read -r selected_context
    fi
    
    if [[ -z "$selected_context" ]]; then
        k8s_log info "No context selected"
        return 0
    fi
    
    if [[ "$selected_context" == "$current_context" ]]; then
        k8s_log info "Already using context: $selected_context"
        return 0
    fi
    
    kubectl config use-context "$selected_context"
    K8S_LAST_CONTEXT="$current_context"
    k8s_log success "Switched to context: $selected_context"
    
    # Show cluster info
    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -1)
    k8s_log info "Cluster: $cluster_info"
    
    # Clear default namespace when switching contexts
    K8S_DEFAULT_NAMESPACE=""
}

# Go back to previous context
k8s_context_back() {
    if [[ -z "$K8S_LAST_CONTEXT" ]]; then
        k8s_log warn "No previous context available"
        return 1
    fi
    
    local current_context=$(kubectl config current-context 2>/dev/null)
    kubectl config use-context "$K8S_LAST_CONTEXT"
    K8S_LAST_CONTEXT="$current_context"
    k8s_log success "Switched back to context: $(kubectl config current-context)"
}

# ════════════════════════════════════════════════════════════════════════════════
# SEARCH AND UTILITY FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

# Multi-resource search
k8s_search() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local search_term="${parsed_args[1]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Searching in namespace: $namespace"
    fi
    
    if [[ -z "$search_term" ]]; then
        echo -e "${K8S_CYAN}Enter search term:${K8S_NC}"
        read -r search_term
    fi
    
    if [[ -z "$search_term" ]]; then
        k8s_log error "No search term provided"
        return 1
    fi
    
    k8s_log info "Searching for: $search_term"
    
    local resource_types=("pods" "services" "deployments" "configmaps" "secrets" "ingresses" "jobs" "cronjobs")
    
    for resource_type in "${resource_types[@]}"; do
        echo -e "\n${K8S_BLUE}=== ${resource_type^^} ===${K8S_NC}"
        local results=$(kubectl get "$resource_type" $ns_flag 2>/dev/null | grep -i "$search_term" || true)
        if [[ -n "$results" ]]; then
            if command -v bat &> /dev/null; then
                echo "$results" | bat --style=plain --paging=never
            else
                echo "$results"
            fi
        else
            echo "No ${resource_type} found matching '$search_term'"
        fi
    done
    
    # Search in resource content
    echo -e "\n${K8S_BLUE}=== CONTENT SEARCH ===${K8S_NC}"
    k8s_log info "Searching in resource definitions..."
    
    for resource_type in "${resource_types[@]}"; do
        local content_matches=$(kubectl get "$resource_type" $ns_flag -o yaml 2>/dev/null | grep -i "$search_term" || true)
        if [[ -n "$content_matches" ]]; then
            echo -e "\n${K8S_CYAN}Found in $resource_type definitions:${K8S_NC}"
            if command -v bat &> /dev/null; then
                echo "$content_matches" | bat --style=plain --paging=never
            else
                echo "$content_matches"
            fi
        fi
    done
}

# Cluster information and health check
k8s_cluster_info() {
    k8s_check_kubectl || return 1
    
    echo -e "${K8S_BOLD}${K8S_BLUE}=== Kubernetes Cluster Information ===${K8S_NC}"
    
    # Basic cluster info
    echo -e "\n${K8S_CYAN}Cluster Info:${K8S_NC}"
    kubectl cluster-info
    
    # Current context and namespace
    echo -e "\n${K8S_CYAN}Current Context:${K8S_NC}"
    local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
    local current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
    echo "Context: $current_context"
    echo "Namespace: $current_namespace"
    
    # Node information
    echo -e "\n${K8S_CYAN}Nodes:${K8S_NC}"
    kubectl get nodes -o wide
    
    # Namespace summary
    echo -e "\n${K8S_CYAN}Namespaces:${K8S_NC}"
    kubectl get namespaces
    
    # Component status (if available)
    echo -e "\n${K8S_CYAN}Component Status:${K8S_NC}"
    kubectl get componentstatuses 2>/dev/null || echo "Component status not available"
    
    # Resource usage (if metrics available)
    if kubectl top nodes &>/dev/null; then
        echo -e "\n${K8S_CYAN}Node Resource Usage:${K8S_NC}"
        kubectl top nodes
    fi
    
    # Check for common issues
    echo -e "\n${K8S_CYAN}Health Check:${K8S_NC}"
    local unhealthy_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | tail -n +2)
    if [[ -n "$unhealthy_pods" ]]; then
        echo -e "${K8S_YELLOW}Unhealthy pods found:${K8S_NC}"
        echo "$unhealthy_pods"
    else
        echo -e "${K8S_GREEN}All pods are healthy${K8S_NC}"
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# ADVANCED FEATURES
# ════════════════════════════════════════════════════════════════════════════════

# Kubernetes events viewer
k8s_events() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Viewing events in namespace: $namespace"
    else
        k8s_log info "Viewing events in all namespaces"
        ns_flag="--all-namespaces"
    fi
    
    local actions=(
        "recent:Show recent events"
        "watch:Watch events in real-time"
        "warnings:Show warning events only"
        "errors:Show error events only"
        "by-object:Filter by object name"
        "by-reason:Filter by reason"
    )
    
    local action=""
    if command -v fzf &> /dev/null; then
        action=$(printf '%s\n' "${actions[@]}" | \
            fzf --header="Event viewing options" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "${K8S_CYAN}Event viewing options:${K8S_NC}"
        for i in "${!actions[@]}"; do
            echo "$((i+1)). $(echo "${actions[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter action number:${K8S_NC}"
        read -r action_num
        action=$(echo "${actions[$((action_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$action" ]] && return 0
    
    case "$action" in
        "recent")
            kubectl get events $ns_flag --sort-by=.metadata.creationTimestamp | tail -20
            ;;
        "watch")
            kubectl get events $ns_flag --watch
            ;;
        "warnings")
            kubectl get events $ns_flag --field-selector type=Warning --sort-by=.metadata.creationTimestamp
            ;;
        "errors")
            kubectl get events $ns_flag --field-selector type!=Normal --sort-by=.metadata.creationTimestamp
            ;;
        "by-object")
            echo -e "${K8S_CYAN}Enter object name to filter:${K8S_NC}"
            read -r object_name
            kubectl get events $ns_flag --field-selector involvedObject.name="$object_name" --sort-by=.metadata.creationTimestamp
            ;;
        "by-reason")
            echo -e "${K8S_CYAN}Enter reason to filter (e.g., Failed, Pulled, Created):${K8S_NC}"
            read -r reason
            kubectl get events $ns_flag --field-selector reason="$reason" --sort-by=.metadata.creationTimestamp
            ;;
    esac
}

# Resource cleanup helper
k8s_cleanup() {
    k8s_check_kubectl || return 1
    
    local parsed_args=($(k8s_parse_namespace "$@"))
    local namespace="${parsed_args[0]}"
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
        k8s_log info "Cleanup in namespace: $namespace"
    fi
    
    local cleanup_types=(
        "failed-pods:Clean up failed/completed pods"
        "old-replicasets:Clean up old replica sets"
        "unused-configmaps:Find potentially unused configmaps"
        "unused-secrets:Find potentially unused secrets"
        "evicted-pods:Clean up evicted pods"
        "completed-jobs:Clean up completed jobs"
    )
    
    local cleanup_type=""
    if command -v fzf &> /dev/null; then
        cleanup_type=$(printf '%s\n' "${cleanup_types[@]}" | \
            fzf --header="Select cleanup operation" \
                --delimiter=':' \
                --with-nth=1 | \
            cut -d':' -f1)
    else
        echo -e "${K8S_CYAN}Cleanup options:${K8S_NC}"
        for i in "${!cleanup_types[@]}"; do
            echo "$((i+1)). $(echo "${cleanup_types[i]}" | cut -d':' -f1)"
        done
        echo -e "\n${K8S_CYAN}Enter cleanup type number:${K8S_NC}"
        read -r cleanup_num
        cleanup_type=$(echo "${cleanup_types[$((cleanup_num-1))]}" | cut -d':' -f1)
    fi
    
    [[ -z "$cleanup_type" ]] && return 0
    
    case "$cleanup_type" in
        "failed-pods")
            local failed_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Failed -o name 2>/dev/null)
            if [[ -n "$failed_pods" ]]; then
                echo -e "${K8S_YELLOW}Failed pods found:${K8S_NC}"
                kubectl get pods $ns_flag --field-selector=status.phase=Failed
                echo -e "\n${K8S_YELLOW}Delete these pods? (y/N)${K8S_NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo "$failed_pods" | xargs kubectl delete $ns_flag
                    k8s_log success "Failed pods cleaned up"
                fi
            else
                k8s_log info "No failed pods found"
            fi
            ;;
        "old-replicasets")
            local old_rs=$(kubectl get replicasets $ns_flag -o json | jq -r '.items[] | select(.spec.replicas==0) | .metadata.name' 2>/dev/null)
            if [[ -n "$old_rs" ]]; then
                echo -e "${K8S_YELLOW}Old replica sets with 0 replicas:${K8S_NC}"
                echo "$old_rs"
                echo -e "\n${K8S_YELLOW}Delete these replica sets? (y/N)${K8S_NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo "$old_rs" | xargs kubectl delete replicaset $ns_flag
                    k8s_log success "Old replica sets cleaned up"
                fi
            else
                k8s_log info "No old replica sets found"
            fi
            ;;
        "evicted-pods")
            local evicted_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Failed -o json | \
                jq -r '.items[] | select(.status.reason=="Evicted") | .metadata.name' 2>/dev/null)
            if [[ -n "$evicted_pods" ]]; then
                echo -e "${K8S_YELLOW}Evicted pods found:${K8S_NC}"
                echo "$evicted_pods"
                echo -e "\n${K8S_YELLOW}Delete these pods? (y/N)${K8S_NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo "$evicted_pods" | xargs kubectl delete pod $ns_flag
                    k8s_log success "Evicted pods cleaned up"
                fi
            else
                k8s_log info "No evicted pods found"
            fi
            ;;
        "completed-jobs")
            local completed_jobs=$(kubectl get jobs $ns_flag --field-selector=status.conditions[0].type=Complete -o name 2>/dev/null)
            if [[ -n "$completed_jobs" ]]; then
                echo -e "${K8S_YELLOW}Completed jobs found:${K8S_NC}"
                kubectl get jobs $ns_flag --field-selector=status.conditions[0].type=Complete
                echo -e "\n${K8S_YELLOW}Delete these jobs? (y/N)${K8S_NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo "$completed_jobs" | xargs kubectl delete $ns_flag
                    k8s_log success "Completed jobs cleaned up"
                fi
            else
                k8s_log info "No completed jobs found"
            fi
            ;;
        "unused-configmaps"|"unused-secrets")
            local resource_type=${cleanup_type#unused-}
            k8s_log info "Analyzing $resource_type usage..."
            k8s_log warn "This is a complex operation that requires analyzing pod specs"
            k8s_log info "Consider using tools like 'popeye' or 'kube-score' for comprehensive analysis"
            kubectl get "$resource_type" $ns_flag
            ;;
    esac
}

# ════════════════════════════════════════════════════════════════════════════════
# HELP AND UTILITY FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

# Comprehensive help system
k8s_help() {
    local help_topic="$1"
    
    if [[ -z "$help_topic" ]]; then
        cat << 'EOF' | if command -v bat &> /dev/null; then bat --language=markdown --style=plain --paging=always; else less; fi

# Kubernetes Complete Toolkit Help

## 🚀 Core Resource Management
| Function | Description | Usage |
|----------|-------------|-------|
| `k8s_pods` | Interactive pod operations | `k8s_pods [-n namespace]` |
| `k8s_services` | Interactive service management | `k8s_services [-n namespace]` |
| `k8s_deployments` | Interactive deployment operations | `k8s_deployments [-n namespace]` |
| `k8s_namespaces` | Interactive namespace management | `k8s_namespaces` |

## 📁 Configuration Management  
| Function | Description | Usage |
|----------|-------------|-------|
| `k8s_configs` | ConfigMap/Secret management | `k8s_configs [-n namespace]` |
| `k8s_browse` | Browse resources with file manager | `k8s_browse [-n namespace]` |

## 🔍 Monitoring & Troubleshooting
| Function | Description | Usage |
|----------|-------------|-------|
| `k8s_logs` | Interactive log viewer | `k8s_logs [-n namespace]` |
| `k8s_top` | Resource usage monitoring | `k8s_top [-n namespace]` |
| `k8s_events` | View cluster events | `k8s_events [-n namespace]` |

## 🌐 Context & Cluster Management
| Function | Description | Usage |
|----------|-------------|-------|
| `k8s_context` | Switch contexts | `k8s_context` |
| `k8s_context_back` | Go back to previous context | `k8s_context_back` |
| `k8s_cluster_info` | Show cluster information | `k8s_cluster_info` |

## 🔧 Utilities
| Function | Description | Usage |
|----------|-------------|-------|
| `k8s_search` | Multi-resource search | `k8s_search [-n namespace] [term]` |
| `k8s_cleanup` | Resource cleanup helper | `k8s_cleanup [-n namespace]` |
| `k8s_set_default_namespace` | Set default namespace | `k8s_set_default_namespace <namespace>` |

## 📋 Configuration
| Function | Description | Usage |
|----------|-------------|-------|
| `k8s_help` | Show help (this screen) | `k8s_help [topic]` |

## 💡 Tips
- Use `-n <namespace>` with any function to work in a specific namespace
- Set a default namespace: `k8s_set_default_namespace production`
- All functions support both interactive (fzf) and manual selection
- Press Ctrl+C to cancel any operation
- Use `k8s_help <function_name>` for detailed help on specific functions

## 🎨 Enhanced Features
- **fzf integration**: Fuzzy finding for all selections
- **bat integration**: Syntax highlighting for YAML/logs
- **yazi integration**: Visual file browsing
- **Multi-container support**: Automatic container detection
- **Safety checks**: Confirmation prompts for destructive operations
- **Context awareness**: Remembers previous context
- **Comprehensive logging**: Colored output with different log levels

For detailed examples, see the documentation or use `k8s_help examples`.

EOF
        return 0
    fi
    
    # Show help for specific functions
    case "$help_topic" in
        "examples")
            cat << 'EOF' | if command -v bat &> /dev/null; then bat --language=markdown --style=plain --paging=always; else less; fi

# Kubernetes Toolkit Examples

## Daily Workflow Examples

### Morning Health Check
```bash
k8s_cluster_info                    # Check cluster status
k8s_namespaces                      # Browse namespaces
k8s_events -n production           # Check recent events
k8s_search "error|fail|crash"      # Find issues
```

### Debugging Application Issues
```bash
k8s_pods -n production             # Find problematic pod
# Select pod → choose "logs" or "describe"
# For deeper investigation: choose "exec-bash"

k8s_events -n production           # Check related events
k8s_top -n production              # Check resource usage
```

### Deployment Management
```bash
k8s_deployments -n staging         # Select deployment
# Choose "scale" to adjust replicas
# Choose "restart" to restart deployment
# Choose "rollout-status" to monitor

k8s_context                        # Switch to production
k8s_deployments -n production      # Repeat for production
```

### Configuration Updates
```bash
k8s_browse -n production           # Browse all resources visually
k8s_configs -n production          # Edit ConfigMaps/Secrets
# Select ConfigMap → choose "edit"

k8s_deployments -n production      # Restart affected services
# Select deployment → choose "restart"
```

### Resource Cleanup
```bash
k8s_cleanup -n staging             # Clean up staging environment
# Choose "failed-pods" or "completed-jobs"

k8s_events -n staging              # Verify cleanup
```

## Advanced Usage

### Multi-Environment Management
```bash
# Set up different default namespaces per context
k8s_context                        # Switch to staging
k8s_set_default_namespace staging

k8s_context                        # Switch to production  
k8s_set_default_namespace production

# Now functions will use the appropriate namespace automatically
k8s_pods                           # Uses production namespace
k8s_context_back                   # Switch back to staging
k8s_pods                           # Uses staging namespace
```

### Monitoring Workflows
```bash
# Terminal 1: Monitor resource usage
k8s_top -n production
# Choose "watch" for continuous monitoring

# Terminal 2: Follow application logs
k8s_logs -n production
# Select app pod → choose "follow"

# Terminal 3: Watch events
k8s_events -n production
# Choose "watch"
```

### Troubleshooting Workflows
```bash
# Step 1: Identify the problem
k8s_search -n production "nginx"   # Find nginx-related resources
k8s_events -n production           # Check recent events

# Step 2: Investigate specific resources
k8s_pods -n production             # Check pod status
# Select problematic pod → choose "describe" or "logs"

# Step 3: Take corrective action
k8s_deployments -n production      # Restart deployment if needed
# Select deployment → choose "restart"
```

EOF
            ;;
        *)
            echo "Help topic '$help_topic' not found. Available topics: examples"
            ;;
    esac
}

# Show toolkit status and information
k8s_status() {
    echo -e "${K8S_BOLD}${K8S_BLUE}Kubernetes Toolkit Status${K8S_NC}"
    echo -e "Version: $K8S_TOOLKIT_VERSION"
    echo -e "Author: $K8S_TOOLKIT_AUTHOR"
    echo
    
    # Current configuration
    echo -e "${K8S_CYAN}Configuration:${K8S_NC}"
    echo -e "Default namespace: ${K8S_DEFAULT_NAMESPACE:-not set}"
    echo -e "Previous context: ${K8S_LAST_CONTEXT:-none}"
    echo -e "Debug mode: $K8S_TOOLKIT_DEBUG"
    echo
    
    # Tool availability
    echo -e "${K8S_CYAN}Tool Availability:${K8S_NC}"
    local tools=("kubectl" "fzf" "bat" "yazi")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "✅ $tool"
        else
            echo -e "❌ $tool"
        fi
    done
    
    # Current cluster info
    if k8s_check_kubectl &>/dev/null; then
        echo
        echo -e "${K8S_CYAN}Current Cluster:${K8S_NC}"
        echo -e "Context: $(kubectl config current-context 2>/dev/null || echo 'none')"
        echo -e "Namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo 'default')"
        echo -e "Server: $(kubectl cluster-info 2>/dev/null | head -1 | grep -o 'https://[^[:space:]]*' || echo 'unknown')"
    else
        echo
        echo -e "${K8S_YELLOW}No cluster connection available${K8S_NC}"
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# INITIALIZATION AND ALIASES
# ════════════════════════════════════════════════════════════════════════════════

# Initialize toolkit
k8s_init() {
    k8s_log info "Initializing Kubernetes Toolkit v$K8S_TOOLKIT_VERSION"
    
    # Check tools
    k8s_check_tools
    
    # Create useful aliases if they don't conflict
    if ! command -v kpods &> /dev/null; then
        alias kpods='k8s_pods'
    fi
    
    if ! command -v ksvcs &> /dev/null; then
        alias ksvcs='k8s_services'
    fi
    
    if ! command -v kdeps &> /dev/null; then
        alias kdeps='k8s_deployments'
    fi
    
    if ! command -v kns &> /dev/null; then
        alias kns='k8s_namespaces'
    fi
    
    if ! command -v kconf &> /dev/null; then
        alias kconf='k8s_configs'
    fi
    
    if ! command -v kbrowse &> /dev/null; then
        alias kbrowse='k8s_browse'
    fi
    
    if ! command -v klogs &> /dev/null; then
        alias klogs='k8s_logs'
    fi
    
    if ! command -v ktop &> /dev/null; then
        alias ktop='k8s_top'
    fi
    
    if ! command -v kctx &> /dev/null; then
        alias kctx='k8s_context'
    fi
    
    if ! command -v kctxb &> /dev/null; then
        alias kctxb='k8s_context_back'
    fi
    
    if ! command -v ksearch &> /dev/null; then
        alias ksearch='k8s_search'
    fi
    
    if ! command -v kevents &> /dev/null; then
        alias kevents='k8s_events'
    fi
    
    if ! command -v kcleanup &> /dev/null; then
        alias kcleanup='k8s_cleanup'
    fi
    
    if ! command -v kinfo &> /dev/null; then
        alias kinfo='k8s_cluster_info'
    fi
    
    if ! command -v khelp &> /dev/null; then
        alias khelp='k8s_help'
    fi
    
    if ! command -v kstatus &> /dev/null; then
        alias kstatus='k8s_status'
    fi
    
    k8s_log success "Kubernetes Toolkit initialized!"
    k8s_log info "Type 'khelp' to see available functions"
    k8s_log info "Type 'kstatus' to see toolkit status"
}

# Auto-initialize on source
k8s_init