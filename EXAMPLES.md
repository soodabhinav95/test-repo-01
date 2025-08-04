# Practical Kubernetes Operations Examples

This document showcases real-world scenarios and how to efficiently handle them using the `fzf`, `yazi`, and `bat` enhanced Kubernetes functions.

## Quick Start Examples

### 1. Morning Cluster Health Check
```bash
# Quick overview of all namespaces
kns
# Select "get-all" to see overview of each namespace

# Check resource usage
ktop
# Select "pods" or "nodes" to monitor resource consumption

# Search for any failing pods
ksearch "error\|failed\|crash"
```

### 2. Debugging a Failing Application
```bash
# Find the problematic pod
kpod -n production
# fzf will show all pods with preview - look for restart counts

# Once pod is selected, choose:
# - "logs" to see recent logs with bat syntax highlighting
# - "logs -f" to follow logs in real-time
# - "describe" to see detailed pod information
# - "exec bash" to get into the container for investigation
```

### 3. Scaling Applications During High Traffic
```bash
# Find the deployment that needs scaling
kdep -n production
# Select your deployment from fzf interface

# Choose "scale" action
# Enter new replica count (e.g., 10)

# Monitor the scaling progress
kdep -n production
# Select same deployment and choose "rollout-status"
```

## Day-to-Day Operational Scenarios

### Scenario 1: Investigating Performance Issues

**Problem**: Application is slow, need to investigate resource usage and logs.

```bash
# Step 1: Check resource usage across the cluster
ktop
# Select "nodes" to see if any nodes are under pressure

# Step 2: Check pod resource usage in specific namespace
ktop -n production
# Select "pods" to see which pods are consuming most resources

# Step 3: Examine logs of high-resource pods
klogs -n production
# Select the problematic pod
# Choose "view-recent" to see last 100 lines with syntax highlighting

# Step 4: Get into the container if needed
kpod -n production
# Select the pod, then "exec bash" or "exec sh"
```

### Scenario 2: Configuration Management

**Problem**: Need to update configuration across multiple services.

```bash
# Step 1: Browse and examine current configurations
kbrowse -n production
# Yazi will open with all resources exported as YAML files
# Navigate through configmaps/ and secrets/ directories

# Step 2: View specific ConfigMap
kconfig -n production
# Select "configmap"
# Choose the specific ConfigMap
# Select "view" to see current values with bat syntax highlighting

# Step 3: Edit the configuration
kconfig -n production
# Select "configmap"
# Choose the ConfigMap to edit
# Select "edit" to modify in your default editor

# Step 4: Restart deployments that use this config
kdep -n production
# Select deployment
# Choose "restart"
```

### Scenario 3: Multi-Environment Deployments

**Problem**: Need to deploy and verify across multiple environments.

```bash
# Step 1: Switch to staging environment
kctx
# Select staging context

# Step 2: Check current deployment status
kdep -n my-app
# Select your deployment
# Choose "describe" to see current image and status

# Step 3: Update deployment
kdep -n my-app
# Select deployment
# Choose "edit" to update image tag

# Step 4: Monitor rollout
kdep -n my-app
# Select deployment
# Choose "rollout-status"

# Step 5: Verify in production
kctx
# Select production context
# Repeat steps 2-4 for production deployment
```

### Scenario 4: Incident Response

**Problem**: Service is down, need to quickly diagnose and fix.

```bash
# Step 1: Quick search for any obvious failures
ksearch -n production "error\|fail\|down"

# Step 2: Check service status
ksvc -n production
# Select the problematic service
# Choose "describe" to see endpoints and configuration

# Step 3: Check associated pods
kpod -n production
# Look for pods with high restart counts or crash status
# Select problematic pod and choose "logs" for recent logs

# Step 4: Get detailed pod information
kpod -n production
# Select the pod
# Choose "describe" to see events and current status

# Step 5: If needed, restart the deployment
kdep -n production
# Select the deployment
# Choose "restart"
```

## Advanced Usage Patterns

### Log Analysis Workflow
```bash
# Save logs for analysis
klogs -n production
# Select pod
# Choose "save-to-file"
# This saves timestamped log file

# Compare logs from different containers
klogs -n production
# Select multi-container pod
# Choose container 1, save logs
# Repeat for container 2
# Use diff tool to compare: diff app-container1.log app-container2.log
```

### Configuration Audit
```bash
# Export all configs for review
kbrowse -n production
# Browse through configmaps/ and secrets/
# Use yazi's preview to quickly scan configurations
# Press 'q' to exit when done

# Search for specific configuration keys
ksearch -n production "database"  # Find all resources mentioning database
ksearch -n production "secret"    # Find all resources mentioning secrets
```

### Resource Cleanup
```bash
# Find unused ConfigMaps
kconfig -n old-project
# Browse through and delete unused ones

# Clean up failed pods
ksearch -n production "failed\|error"
# Then use kpod to delete problematic pods

# Remove old deployments
kdep -n staging
# Select old deployments and delete them
```

## Integration with Other Tools

### Using with tmux for Multi-Environment Monitoring
```bash
# Terminal 1: Production monitoring
tmux new-session -d -s k8s-prod
tmux send-keys -t k8s-prod 'kctx' Enter
# Select production context
tmux send-keys -t k8s-prod 'ktop -n production' Enter

# Terminal 2: Staging monitoring  
tmux new-window -t k8s-prod
tmux send-keys -t k8s-prod 'kctx' Enter
# Select staging context
tmux send-keys -t k8s-prod 'klogs -n staging' Enter

# Attach to session
tmux attach-session -t k8s-prod
```

### Integration with Git Workflows
```bash
# Before deployment: check current state
kbrowse -n production
# Export current configurations
# Navigate to deployments/ folder in yazi
# Copy important configs to git repository for backup

# After deployment: verify changes
kdep -n production
# Select deployment
# Choose "rollout-status"
# Use "rollout-history" to see deployment history
```

## Performance Tips

### 1. Use Namespace-Specific Operations
```bash
# Instead of searching all namespaces
kpod -n specific-namespace  # Much faster

# Set default namespace context to avoid -n flag
kns
# Select namespace and choose "set-context"
```

### 2. Leverage fzf Preview for Quick Decisions
```bash
# The preview window shows key information
# No need to describe every resource
# Use preview to quickly identify the right resource
```

### 3. Combine with Shell History
```bash
# Use shell history with fzf for repeated operations
# Press Ctrl+R and type "kpod" to find recent pod operations
```

## Troubleshooting Common Issues

### Issue: fzf Preview Not Working
```bash
# Check if preview command works manually
kubectl describe pod pod-name -n namespace

# Ensure preview dependencies are installed
which kubectl
```

### Issue: Yazi Not Opening Files Properly
```bash
# Configure yazi to use bat for YAML files
# Edit ~/.config/yazi/yazi.toml
[opener]
yaml = [ { run = 'bat "$@"', block = true } ]
```

### Issue: Colors Not Showing in bat
```bash
# Force color output
export BAT_STYLE="grid,numbers,changes"
export BAT_THEME="GitHub"
```

## Best Practices

1. **Always verify the context and namespace** before operations
2. **Use the preview window** to confirm resource selection
3. **Take advantage of confirmation prompts** for destructive operations
4. **Save important logs** before investigating with log following
5. **Use search functions** to quickly find resources across the cluster
6. **Leverage yazi browsing** for configuration audits and reviews

These functions transform tedious kubectl commands into interactive, efficient workflows that significantly speed up daily Kubernetes operations.