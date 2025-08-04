# Kubernetes Complete Toolkit Setup Guide

## 🚀 Quick Setup

### 1. Download and Install
```bash
# Download the toolkit
curl -o ~/.k8s-toolkit.sh https://raw.githubusercontent.com/your-repo/k8s-toolkit.sh

# Make it executable
chmod +x ~/.k8s-toolkit.sh

# Add to your shell profile
echo 'source ~/.k8s-toolkit.sh' >> ~/.bashrc
source ~/.bashrc
```

### 2. Verify Installation
```bash
# Check toolkit status
kstatus

# View available functions
khelp
```

## 🛠️ Function Reference

### Core Resource Management
- **`k8s_pods`** / **`kpods`** - Interactive pod operations
- **`k8s_services`** / **`ksvcs`** - Service management  
- **`k8s_deployments`** / **`kdeps`** - Deployment operations
- **`k8s_namespaces`** / **`kns`** - Namespace management

### Configuration Management
- **`k8s_configs`** / **`kconf`** - ConfigMap/Secret management
- **`k8s_browse`** / **`kbrowse`** - Visual resource browsing

### Monitoring & Troubleshooting
- **`k8s_logs`** / **`klogs`** - Interactive log viewer
- **`k8s_top`** / **`ktop`** - Resource usage monitoring
- **`k8s_events`** / **`kevents`** - Cluster events

### Context & Cluster Management
- **`k8s_context`** / **`kctx`** - Context switching
- **`k8s_context_back`** / **`kctxb`** - Previous context
- **`k8s_cluster_info`** / **`kinfo`** - Cluster information

### Utilities
- **`k8s_search`** / **`ksearch`** - Multi-resource search
- **`k8s_cleanup`** / **`kcleanup`** - Resource cleanup
- **`k8s_help`** / **`khelp`** - Help system
- **`k8s_status`** / **`kstatus`** - Toolkit status

## 💡 Key Features

### ✅ Fixed Issues from Original Version
- **Unique function names** - No conflicts with existing commands
- **Robust namespace handling** - Fixed `-n namespace` parameter parsing
- **Better error handling** - Graceful fallbacks when tools are missing
- **Comprehensive functionality** - All Kubernetes operations in one toolkit

### 🎯 Enhanced Capabilities
- **Smart namespace management** - Set default namespaces per context
- **Multi-container support** - Automatic container detection and selection
- **Advanced search** - Search across all resource types and content
- **Resource cleanup** - Automated cleanup of failed/old resources
- **Context switching** - Remember and switch between contexts easily
- **Visual browsing** - Export and browse resources with file managers

## 🔧 Configuration Options

### Set Default Namespace
```bash
# Set default namespace for current context
k8s_set_default_namespace production

# Now all functions will use 'production' by default
kpods  # Equivalent to kpods -n production
```

### Enable Debug Mode
```bash
# Add to your shell profile for debugging
export K8S_TOOLKIT_DEBUG=true
```

### Customize Tool Behavior
```bash
# Configure fzf for better experience
export FZF_DEFAULT_OPTS='--height 80% --layout reverse --border'

# Configure bat theme
export BAT_THEME="GitHub"
```

## 📖 Usage Examples

### Daily Operations
```bash
# Morning health check
kstatus                    # Check toolkit and cluster status
kinfo                      # Show cluster information
kevents -n production      # Check recent events

# Work with pods
kpods -n production        # Interactive pod operations
# Select pod → choose action (logs, exec, describe, etc.)

# Monitor resources
ktop -n production         # Resource usage monitoring
# Choose "watch" for continuous monitoring
```

### Debugging Workflow
```bash
# Step 1: Find the issue
ksearch -n production "error"  # Search for error-related resources
kevents -n production          # Check events

# Step 2: Investigate specific resource
kpods -n production           # Select problematic pod
# Choose "logs" → "errors" to filter error logs
# Choose "describe" for detailed information
# Choose "exec-bash" to get inside container

# Step 3: Fix the issue
kdeps -n production           # Select deployment
# Choose "restart" to restart deployment
# Choose "rollout-status" to monitor progress
```

### Configuration Management
```bash
# Browse all resources visually
kbrowse -n production         # Opens yazi file manager
# Navigate through exported YAML files

# Edit configurations
kconf -n production           # Select ConfigMap or Secret
# Choose "edit" to modify configuration

# Apply changes
kdeps -n production           # Restart affected deployments
# Choose "restart"
```

### Multi-Environment Workflow
```bash
# Set up environments
kctx                          # Switch to staging
k8s_set_default_namespace staging

kctx                          # Switch to production
k8s_set_default_namespace production

# Now work seamlessly across environments
kpods                         # Uses production namespace
kctxb                         # Switch back to staging
kpods                         # Uses staging namespace
```

## 🔍 Advanced Features

### Search Capabilities
```bash
# Search by name
ksearch nginx                 # Find all nginx-related resources

# Search with namespace
ksearch -n production "redis" # Search in specific namespace

# Content search
ksearch "database"            # Search in resource definitions
```

### Resource Cleanup
```bash
# Clean up failed resources
kcleanup -n staging
# Choose from:
# - failed-pods: Remove failed/completed pods
# - old-replicasets: Remove old replica sets
# - evicted-pods: Remove evicted pods
# - completed-jobs: Remove completed jobs
```

### Log Analysis
```bash
klogs -n production
# Select pod → Choose from:
# - tail: Recent logs (100 lines)
# - follow: Real-time log following
# - search: Search in logs
# - errors: Filter error lines only
# - save: Save logs to file
```

## 🎨 Integration with Other Tools

### tmux Integration
```bash
# Terminal 1: Monitor production
tmux new-session -d -s k8s-prod
tmux send-keys 'kctx; kns' Enter  # Set context and namespace
tmux send-keys 'ktop -n production' Enter

# Terminal 2: Monitor staging  
tmux new-window
tmux send-keys 'kctx; kns' Enter
tmux send-keys 'klogs -n staging' Enter
```

### Git Workflow Integration
```bash
# Before deployment
kbrowse -n production         # Export current state
# Copy important configs to git for backup

# After deployment
kdeps -n production          # Check deployment status
kevents -n production        # Verify no issues
```

## 🆘 Troubleshooting

### Common Issues

1. **Functions not working after sourcing**
   ```bash
   # Check if toolkit loaded
   kstatus
   
   # Reload if needed
   source ~/.k8s-toolkit.sh
   ```

2. **Namespace flag not working**
   ```bash
   # Use the new functions with proper parsing
   kpods -n production    # ✅ Works correctly
   
   # Set default namespace to avoid typing -n every time
   k8s_set_default_namespace production
   kpods                  # ✅ Uses production namespace
   ```

3. **Missing tools warnings**
   ```bash
   # Install missing tools
   sudo apt install fzf bat
   
   # For yazi (if needed)
   cargo install --locked yazi-fm
   ```

4. **Context issues**
   ```bash
   # Check current context
   kinfo
   
   # Switch contexts
   kctx
   
   # Go back to previous
   kctxb
   ```

## 🚀 Pro Tips

1. **Use aliases** - All functions have short aliases (kpods, ksvcs, etc.)
2. **Set default namespaces** - Avoid typing `-n namespace` repeatedly
3. **Use fzf shortcuts** - Ctrl+R to search history, Ctrl+C to cancel
4. **Save logs** - Use the "save" option in klogs for later analysis
5. **Browse visually** - Use kbrowse to get an overview of all resources
6. **Chain operations** - Use context switching with namespace defaults for multi-env workflows

This toolkit transforms your Kubernetes experience from command memorization to intuitive, interactive operations! 🎉