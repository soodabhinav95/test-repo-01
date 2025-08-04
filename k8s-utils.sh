#!/bin/bash

# Kubernetes Utility Functions with fzf, yazi, and bat
# Source this file in your .bashrc or .zshrc: source /path/to/k8s-utils.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Utility function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed or not in PATH${NC}"
        return 1
    fi
}

# 1. Interactive Pod Selection and Operations
kpod() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local pod=$(kubectl get pods $namespace -o wide | \
        fzf --header="Select a pod" \
            --preview="kubectl describe pod {1} $namespace" \
            --preview-window=right:50% | \
        awk '{print $1}')
    
    if [[ -n "$pod" ]]; then
        echo -e "${GREEN}Selected pod: $pod${NC}"
        
        local action=$(echo -e "logs\nlogs -f\nexec bash\nexec sh\ndescribe\nedit\ndelete\nport-forward\ncopy-from\ncopy-to" | \
            fzf --header="What would you like to do with $pod?")
        
        case "$action" in
            "logs")
                kubectl logs $pod $namespace | bat --language=log --style=plain
                ;;
            "logs -f")
                kubectl logs -f $pod $namespace
                ;;
            "exec bash")
                kubectl exec -it $pod $namespace -- bash
                ;;
            "exec sh")
                kubectl exec -it $pod $namespace -- sh
                ;;
            "describe")
                kubectl describe pod $pod $namespace | bat --language=yaml --style=plain
                ;;
            "edit")
                kubectl edit pod $pod $namespace
                ;;
            "delete")
                echo -e "${YELLOW}Are you sure you want to delete $pod? (y/N)${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    kubectl delete pod $pod $namespace
                fi
                ;;
            "port-forward")
                echo -e "${CYAN}Enter local:remote port (e.g., 8080:80):${NC}"
                read -r ports
                kubectl port-forward $pod $namespace $ports
                ;;
            "copy-from")
                echo -e "${CYAN}Enter pod path to copy from:${NC}"
                read -r pod_path
                echo -e "${CYAN}Enter local destination:${NC}"
                read -r local_path
                kubectl cp $pod:$pod_path $local_path $namespace
                ;;
            "copy-to")
                echo -e "${CYAN}Enter local file to copy:${NC}"
                read -r local_path
                echo -e "${CYAN}Enter pod destination path:${NC}"
                read -r pod_path
                kubectl cp $local_path $pod:$pod_path $namespace
                ;;
        esac
    fi
}

# 2. Interactive Service Selection and Operations
ksvc() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local service=$(kubectl get services $namespace -o wide | \
        fzf --header="Select a service" \
            --preview="kubectl describe service {1} $namespace" \
            --preview-window=right:50% | \
        awk '{print $1}')
    
    if [[ -n "$service" ]]; then
        echo -e "${GREEN}Selected service: $service${NC}"
        
        local action=$(echo -e "describe\nedit\ndelete\nport-forward\nget-endpoints" | \
            fzf --header="What would you like to do with $service?")
        
        case "$action" in
            "describe")
                kubectl describe service $service $namespace | bat --language=yaml --style=plain
                ;;
            "edit")
                kubectl edit service $service $namespace
                ;;
            "delete")
                echo -e "${YELLOW}Are you sure you want to delete $service? (y/N)${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    kubectl delete service $service $namespace
                fi
                ;;
            "port-forward")
                echo -e "${CYAN}Enter local:remote port (e.g., 8080:80):${NC}"
                read -r ports
                kubectl port-forward service/$service $namespace $ports
                ;;
            "get-endpoints")
                kubectl get endpoints $service $namespace -o yaml | bat --language=yaml
                ;;
        esac
    fi
}

# 3. Interactive Deployment Management
kdep() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local deployment=$(kubectl get deployments $namespace -o wide | \
        fzf --header="Select a deployment" \
            --preview="kubectl describe deployment {1} $namespace" \
            --preview-window=right:50% | \
        awk '{print $1}')
    
    if [[ -n "$deployment" ]]; then
        echo -e "${GREEN}Selected deployment: $deployment${NC}"
        
        local action=$(echo -e "describe\nedit\nscale\nrestart\nrollout-status\nrollout-history\nrollout-undo\ndelete" | \
            fzf --header="What would you like to do with $deployment?")
        
        case "$action" in
            "describe")
                kubectl describe deployment $deployment $namespace | bat --language=yaml --style=plain
                ;;
            "edit")
                kubectl edit deployment $deployment $namespace
                ;;
            "scale")
                echo -e "${CYAN}Enter number of replicas:${NC}"
                read -r replicas
                kubectl scale deployment $deployment $namespace --replicas=$replicas
                ;;
            "restart")
                kubectl rollout restart deployment $deployment $namespace
                ;;
            "rollout-status")
                kubectl rollout status deployment $deployment $namespace
                ;;
            "rollout-history")
                kubectl rollout history deployment $deployment $namespace
                ;;
            "rollout-undo")
                kubectl rollout undo deployment $deployment $namespace
                ;;
            "delete")
                echo -e "${YELLOW}Are you sure you want to delete $deployment? (y/N)${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    kubectl delete deployment $deployment $namespace
                fi
                ;;
        esac
    fi
}

# 4. Interactive Namespace Operations
kns() {
    check_kubectl || return 1
    
    local namespace=$(kubectl get namespaces | \
        fzf --header="Select a namespace" \
            --preview="kubectl get all -n {1}" \
            --preview-window=right:50% | \
        awk '{print $1}')
    
    if [[ -n "$namespace" ]]; then
        echo -e "${GREEN}Selected namespace: $namespace${NC}"
        
        local action=$(echo -e "set-context\nget-all\nget-pods\nget-services\nget-deployments\nget-configmaps\nget-secrets\ndescribe\ndelete" | \
            fzf --header="What would you like to do with $namespace?")
        
        case "$action" in
            "set-context")
                kubectl config set-context --current --namespace=$namespace
                echo -e "${GREEN}Context set to namespace: $namespace${NC}"
                ;;
            "get-all")
                kubectl get all -n $namespace | bat --style=plain
                ;;
            "get-pods")
                kubectl get pods -n $namespace -o wide | bat --style=plain
                ;;
            "get-services")
                kubectl get services -n $namespace -o wide | bat --style=plain
                ;;
            "get-deployments")
                kubectl get deployments -n $namespace -o wide | bat --style=plain
                ;;
            "get-configmaps")
                kubectl get configmaps -n $namespace | bat --style=plain
                ;;
            "get-secrets")
                kubectl get secrets -n $namespace | bat --style=plain
                ;;
            "describe")
                kubectl describe namespace $namespace | bat --language=yaml --style=plain
                ;;
            "delete")
                echo -e "${RED}WARNING: This will delete the entire namespace and all resources in it!${NC}"
                echo -e "${YELLOW}Are you sure you want to delete namespace $namespace? (y/N)${NC}"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    kubectl delete namespace $namespace
                fi
                ;;
        esac
    fi
}

# 5. Interactive ConfigMap/Secret Management
kconfig() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local resource_type=$(echo -e "configmap\nsecret" | \
        fzf --header="Select resource type")
    
    if [[ -n "$resource_type" ]]; then
        local resource=$(kubectl get $resource_type $namespace | \
            fzf --header="Select a $resource_type" \
                --preview="kubectl describe $resource_type {1} $namespace" \
                --preview-window=right:50% | \
            awk '{print $1}')
        
        if [[ -n "$resource" ]]; then
            echo -e "${GREEN}Selected $resource_type: $resource${NC}"
            
            local action=$(echo -e "view\nedit\ndescribe\ndelete\nexport-yaml" | \
                fzf --header="What would you like to do with $resource?")
            
            case "$action" in
                "view")
                    kubectl get $resource_type $resource $namespace -o yaml | bat --language=yaml
                    ;;
                "edit")
                    kubectl edit $resource_type $resource $namespace
                    ;;
                "describe")
                    kubectl describe $resource_type $resource $namespace | bat --language=yaml --style=plain
                    ;;
                "delete")
                    echo -e "${YELLOW}Are you sure you want to delete $resource_type $resource? (y/N)${NC}"
                    read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        kubectl delete $resource_type $resource $namespace
                    fi
                    ;;
                "export-yaml")
                    kubectl get $resource_type $resource $namespace -o yaml > "${resource}-${resource_type}.yaml"
                    echo -e "${GREEN}Exported to ${resource}-${resource_type}.yaml${NC}"
                    ;;
            esac
        fi
    fi
}

# 6. Browse Kubernetes Resources with Yazi
kbrowse() {
    check_kubectl || return 1
    
    # Create temporary directory for resource exports
    local temp_dir=$(mktemp -d)
    local namespace=""
    
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    echo -e "${CYAN}Exporting Kubernetes resources to temporary directory...${NC}"
    
    # Export different resource types
    mkdir -p "$temp_dir/pods" "$temp_dir/services" "$temp_dir/deployments" "$temp_dir/configmaps" "$temp_dir/secrets"
    
    # Export pods
    kubectl get pods $namespace -o name 2>/dev/null | while read -r pod; do
        pod_name=$(basename "$pod")
        kubectl get pod "$pod_name" $namespace -o yaml > "$temp_dir/pods/${pod_name}.yaml" 2>/dev/null
    done
    
    # Export services
    kubectl get services $namespace -o name 2>/dev/null | while read -r svc; do
        svc_name=$(basename "$svc")
        kubectl get service "$svc_name" $namespace -o yaml > "$temp_dir/services/${svc_name}.yaml" 2>/dev/null
    done
    
    # Export deployments
    kubectl get deployments $namespace -o name 2>/dev/null | while read -r dep; do
        dep_name=$(basename "$dep")
        kubectl get deployment "$dep_name" $namespace -o yaml > "$temp_dir/deployments/${dep_name}.yaml" 2>/dev/null
    done
    
    echo -e "${GREEN}Resources exported. Opening with yazi...${NC}"
    echo -e "${YELLOW}Press 'q' to quit yazi when done browsing.${NC}"
    
    # Open with yazi
    if command -v yazi &> /dev/null; then
        yazi "$temp_dir"
    else
        echo -e "${YELLOW}yazi not found, opening with default file manager or ls${NC}"
        ls -la "$temp_dir"
        echo -e "${CYAN}Resources are available in: $temp_dir${NC}"
        echo -e "${CYAN}Use 'bat' to view YAML files, e.g.: bat $temp_dir/pods/pod-name.yaml${NC}"
    fi
    
    # Cleanup
    echo -e "${CYAN}Cleaning up temporary directory...${NC}"
    rm -rf "$temp_dir"
}

# 7. Interactive Log Viewer with Context
klogs() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local pod=$(kubectl get pods $namespace | \
        fzf --header="Select a pod for logs" \
            --preview="kubectl logs {1} $namespace --tail=20" \
            --preview-window=right:50% | \
        awk '{print $1}')
    
    if [[ -n "$pod" ]]; then
        echo -e "${GREEN}Selected pod: $pod${NC}"
        
        # Check if pod has multiple containers
        local containers=$(kubectl get pod $pod $namespace -o jsonpath='{.spec.containers[*].name}')
        local container=""
        
        if [[ $(echo "$containers" | wc -w) -gt 1 ]]; then
            container=$(echo "$containers" | tr ' ' '\n' | \
                fzf --header="Select container")
            if [[ -n "$container" ]]; then
                container="-c $container"
            fi
        fi
        
        local action=$(echo -e "view-recent\nfollow\nview-all\nprevious-logs\nsave-to-file" | \
            fzf --header="Log viewing options")
        
        case "$action" in
            "view-recent")
                kubectl logs $pod $namespace $container --tail=100 | bat --language=log --style=plain
                ;;
            "follow")
                kubectl logs -f $pod $namespace $container
                ;;
            "view-all")
                kubectl logs $pod $namespace $container | bat --language=log --style=plain
                ;;
            "previous-logs")
                kubectl logs $pod $namespace $container --previous | bat --language=log --style=plain
                ;;
            "save-to-file")
                local filename="${pod}-$(date +%Y%m%d-%H%M%S).log"
                kubectl logs $pod $namespace $container > "$filename"
                echo -e "${GREEN}Logs saved to: $filename${NC}"
                ;;
        esac
    fi
}

# 8. Quick Context Switcher
kctx() {
    check_kubectl || return 1
    
    local context=$(kubectl config get-contexts -o name | \
        fzf --header="Select a context" \
            --preview="kubectl config get-contexts {}" \
            --preview-window=right:50%)
    
    if [[ -n "$context" ]]; then
        kubectl config use-context "$context"
        echo -e "${GREEN}Switched to context: $context${NC}"
    fi
}

# 9. Resource Usage Monitor
ktop() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local resource_type=$(echo -e "pods\nnodes" | \
        fzf --header="Select resource type to monitor")
    
    case "$resource_type" in
        "pods")
            if command -v watch &> /dev/null; then
                watch -n 2 "kubectl top pods $namespace"
            else
                kubectl top pods $namespace
            fi
            ;;
        "nodes")
            if command -v watch &> /dev/null; then
                watch -n 2 "kubectl top nodes"
            else
                kubectl top nodes
            fi
            ;;
    esac
}

# 10. Multi-Resource Search and Filter
ksearch() {
    check_kubectl || return 1
    
    local namespace=""
    if [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        namespace="-n $2"
        shift 2
    fi
    
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        echo -e "${CYAN}Enter search term:${NC}"
        read -r search_term
    fi
    
    if [[ -n "$search_term" ]]; then
        echo -e "${GREEN}Searching for: $search_term${NC}"
        echo
        
        echo -e "${BLUE}=== PODS ===${NC}"
        kubectl get pods $namespace | grep -i "$search_term" | bat --style=plain
        echo
        
        echo -e "${BLUE}=== SERVICES ===${NC}"
        kubectl get services $namespace | grep -i "$search_term" | bat --style=plain
        echo
        
        echo -e "${BLUE}=== DEPLOYMENTS ===${NC}"
        kubectl get deployments $namespace | grep -i "$search_term" | bat --style=plain
        echo
        
        echo -e "${BLUE}=== CONFIGMAPS ===${NC}"
        kubectl get configmaps $namespace | grep -i "$search_term" | bat --style=plain
        echo
        
        echo -e "${BLUE}=== SECRETS ===${NC}"
        kubectl get secrets $namespace | grep -i "$search_term" | bat --style=plain
    fi
}

# Help function
khelp() {
    cat << 'EOF' | bat --language=markdown --style=plain

# Kubernetes Utility Functions

## Available Functions:

### 🚀 Core Operations
- `kpod [-n namespace]`     - Interactive pod selection and operations
- `ksvc [-n namespace]`     - Interactive service management  
- `kdep [-n namespace]`     - Interactive deployment management
- `kns`                     - Interactive namespace operations

### 📁 Resource Management
- `kconfig [-n namespace]`  - Interactive ConfigMap/Secret management
- `kbrowse [-n namespace]`  - Browse resources with yazi file manager
- `klogs [-n namespace]`    - Interactive log viewer with context

### 🔍 Navigation & Search  
- `kctx`                    - Quick context switcher
- `ktop [-n namespace]`     - Resource usage monitor
- `ksearch [term] [-n ns]`  - Multi-resource search and filter

### ❓ Help
- `khelp`                   - Show this help message

## Usage Examples:

```bash
# Select and operate on a pod in default namespace
kpod

# Select and operate on a pod in specific namespace  
kpod -n my-namespace

# Browse all resources with yazi
kbrowse

# Search for resources containing "nginx"
ksearch nginx

# Switch contexts interactively
kctx

# View logs interactively
klogs -n production
```

## Features:

✅ Interactive selection with fzf fuzzy finding
✅ Beautiful syntax highlighting with bat  
✅ File browsing with yazi
✅ Live previews and descriptions
✅ Safe operations with confirmations
✅ Multi-container support
✅ Context switching
✅ Resource monitoring

EOF
}

# Aliases for convenience
alias kp='kpod'
alias ks='ksvc' 
alias kd='kdep'
alias kc='kconfig'
alias kb='kbrowse'
alias kl='klogs'
alias kt='ktop'
alias kx='kctx'

echo -e "${GREEN}Kubernetes utility functions loaded!${NC}"
echo -e "${CYAN}Type 'khelp' to see available functions${NC}"