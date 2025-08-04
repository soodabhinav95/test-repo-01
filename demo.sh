#!/bin/bash

# Demo script for Kubernetes utility functions
# This script demonstrates the capabilities without requiring a real cluster

set -e

# Colors for demo output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Demo banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    Kubernetes Utils Demo                     ║
║          Interactive CLI tools with fzf, yazi, bat           ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to show demo sections
demo_section() {
    echo -e "\n${CYAN}═══ $1 ═══${NC}\n"
    sleep 1
}

# Function to show commands with syntax highlighting
show_command() {
    echo -e "${GREEN}$ $1${NC}"
    sleep 0.5
}

# Function to simulate interactive selection
simulate_selection() {
    echo -e "${YELLOW}[Interactive Selection]${NC}"
    echo "┌─ $1 ─┐"
    shift
    for item in "$@"; do
        echo "│ $item"
    done
    echo "└─────────────────────────────────────────┘"
    sleep 1
}

# Check if required tools are available
check_tools() {
    demo_section "Checking Prerequisites"
    
    tools=("kubectl" "fzf" "bat" "yazi")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "✅ $tool is installed"
        else
            echo -e "❌ $tool is not installed"
        fi
    done
    
    echo -e "\n${YELLOW}Note: This demo shows the interface even without a cluster${NC}"
}

# Demo the main functions
demo_functions() {
    demo_section "Available Functions Overview"
    
    cat << EOF
🚀 Core Operations:
  kpod  - Interactive pod selection and operations
  ksvc  - Interactive service management  
  kdep  - Interactive deployment management
  kns   - Interactive namespace operations

📁 Resource Management:
  kconfig - ConfigMap/Secret management
  kbrowse - Browse resources with yazi
  klogs   - Interactive log viewer

🔍 Navigation & Search:
  kctx    - Quick context switcher
  ktop    - Resource usage monitor
  ksearch - Multi-resource search
EOF
}

# Demo interactive pod operations
demo_kpod() {
    demo_section "Interactive Pod Operations (kpod)"
    
    show_command "kpod -n production"
    simulate_selection "Select a pod" \
        "nginx-deployment-7d6bf8fcb5-8wj2x   2/2   Running   0   2d" \
        "redis-master-1234567890-abcde       1/1   Running   0   1d" \
        "api-server-9876543210-fghij         1/1   Running   2   12h"
    
    echo -e "${GREEN}Selected: nginx-deployment-7d6bf8fcb5-8wj2x${NC}"
    
    simulate_selection "What would you like to do?" \
        "logs" \
        "logs -f" \
        "exec bash" \
        "describe" \
        "port-forward" \
        "copy-from" \
        "copy-to"
        
    echo -e "${GREEN}Action: logs selected${NC}"
    echo -e "${BLUE}Output would be displayed with bat syntax highlighting${NC}"
}

# Demo namespace operations
demo_kns() {
    demo_section "Namespace Operations (kns)"
    
    show_command "kns"
    simulate_selection "Select a namespace" \
        "default        Active   30d" \
        "kube-system    Active   30d" \
        "production     Active   15d" \
        "staging        Active   15d"
    
    echo -e "${GREEN}Selected: production${NC}"
    
    simulate_selection "What would you like to do?" \
        "set-context" \
        "get-all" \
        "get-pods" \
        "get-services" \
        "describe"
}

# Demo search functionality
demo_search() {
    demo_section "Multi-Resource Search (ksearch)"
    
    show_command "ksearch nginx"
    echo -e "${GREEN}Searching for: nginx${NC}"
    echo
    
    echo -e "${BLUE}=== PODS ===${NC}"
    echo "nginx-deployment-7d6bf8fcb5-8wj2x   2/2   Running"
    echo "nginx-proxy-abc123                   1/1   Running"
    echo
    
    echo -e "${BLUE}=== SERVICES ===${NC}"
    echo "nginx-service   ClusterIP   10.96.1.100   <none>   80/TCP"
    echo
    
    echo -e "${BLUE}=== DEPLOYMENTS ===${NC}"
    echo "nginx-deployment   2/2   2   2   2d"
}

# Demo configuration browsing
demo_browse() {
    demo_section "Resource Browsing (kbrowse)"
    
    show_command "kbrowse -n production"
    echo -e "${CYAN}Exporting Kubernetes resources to temporary directory...${NC}"
    echo -e "${GREEN}Resources exported. Opening with yazi...${NC}"
    
    cat << 'EOF'
┌─ yazi file browser ─────────────────────────────────────┐
│ 📁 pods/                                               │
│   └── nginx-deployment-7d6bf8fcb5-8wj2x.yaml          │
│   └── redis-master-1234567890-abcde.yaml              │
│ 📁 services/                                           │
│   └── nginx-service.yaml                              │
│   └── redis-service.yaml                              │
│ 📁 deployments/                                        │
│   └── nginx-deployment.yaml                           │
│   └── redis-deployment.yaml                           │
│ 📁 configmaps/                                         │
│ 📁 secrets/                                            │
└─────────────────────────────────────────────────────────┘
EOF
    
    echo -e "${YELLOW}Use arrows to navigate, Enter to view with bat, q to quit${NC}"
}

# Demo context switching
demo_context() {
    demo_section "Context Switching (kctx)"
    
    show_command "kctx"
    simulate_selection "Select a context" \
        "minikube" \
        "production-cluster" \
        "staging-cluster" \
        "dev-cluster"
    
    echo -e "${GREEN}Switched to context: production-cluster${NC}"
}

# Demo log viewing
demo_logs() {
    demo_section "Interactive Log Viewing (klogs)"
    
    show_command "klogs -n production"
    simulate_selection "Select a pod for logs" \
        "nginx-deployment-7d6bf8fcb5-8wj2x   Running" \
        "redis-master-1234567890-abcde       Running" \
        "api-server-9876543210-fghij         Running"
    
    echo -e "${GREEN}Selected: nginx-deployment-7d6bf8fcb5-8wj2x${NC}"
    
    simulate_selection "Log viewing options" \
        "view-recent" \
        "follow" \
        "view-all" \
        "previous-logs" \
        "save-to-file"
    
    echo -e "${GREEN}Action: view-recent selected${NC}"
    echo -e "${BLUE}Logs would be displayed with bat syntax highlighting${NC}"
}

# Demo workflow scenarios
demo_workflows() {
    demo_section "Real-World Workflow Examples"
    
    echo -e "${YELLOW}🌅 Morning Health Check:${NC}"
    echo "1. kns → Browse namespaces"
    echo "2. ktop → Check resource usage"  
    echo "3. ksearch 'error|fail' → Find issues"
    echo
    
    echo -e "${YELLOW}🐛 Debugging Issues:${NC}"
    echo "1. kpod -n production → Find problematic pod"
    echo "2. Select pod → Choose 'logs' for investigation"
    echo "3. Or choose 'exec bash' to get inside container"
    echo
    
    echo -e "${YELLOW}⚙️ Configuration Management:${NC}"
    echo "1. kbrowse -n production → Browse all resources"
    echo "2. kconfig -n production → Edit ConfigMaps/Secrets"
    echo "3. kdep -n production → Restart affected deployments"
    echo
    
    echo -e "${YELLOW}🚀 Deployment Operations:${NC}"
    echo "1. kctx → Switch to target environment"
    echo "2. kdep -n staging → Select deployment"
    echo "3. Choose 'scale' or 'restart' as needed"
    echo "4. Choose 'rollout-status' to monitor"
}

# Show installation steps
demo_installation() {
    demo_section "Quick Installation"
    
    echo "1. Download the script:"
    show_command "curl -o ~/.k8s-utils.sh https://raw.githubusercontent.com/your-repo/k8s-utils.sh"
    echo
    
    echo "2. Add to shell profile:"
    show_command "echo 'source ~/.k8s-utils.sh' >> ~/.bashrc"
    echo
    
    echo "3. Reload shell:"
    show_command "source ~/.bashrc"
    echo
    
    echo "4. Start using:"
    show_command "khelp"
}

# Demo comparison
demo_comparison() {
    demo_section "Before vs After"
    
    echo -e "${RED}Traditional kubectl workflow:${NC}"
    show_command "kubectl get pods -n production"
    show_command "kubectl describe pod nginx-deployment-7d6bf8fcb5-8wj2x -n production"
    show_command "kubectl logs nginx-deployment-7d6bf8fcb5-8wj2x -n production"
    echo
    
    echo -e "${GREEN}With k8s-utils:${NC}"
    show_command "kpod -n production"
    echo "  → Interactive selection → Automatic operations → Beautiful output"
}

# Main demo flow
main() {
    clear
    
    # Run demo sections
    check_tools
    demo_functions
    demo_kpod
    demo_kns
    demo_search
    demo_browse
    demo_context
    demo_logs
    demo_workflows
    demo_comparison
    demo_installation
    
    # Closing
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 Demo Complete!${NC}"
    echo
    echo -e "Ready to transform your Kubernetes workflow?"
    echo -e "📖 See ${BLUE}INSTALL.md${NC} for setup instructions"
    echo -e "📚 See ${BLUE}EXAMPLES.md${NC} for detailed usage scenarios"
    echo -e "❓ Run ${GREEN}khelp${NC} for function reference"
    echo
    echo -e "${YELLOW}Made with ❤️ for the Kubernetes community${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run the demo
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi