# Kubernetes CLI Utilities with fzf, yazi, and bat

🚀 **Transform your Kubernetes workflow** with interactive, intuitive command-line utilities that combine the power of `kubectl` with modern CLI tools.

## ✨ Features

- 🔍 **Interactive resource selection** with `fzf` fuzzy finding
- 🎨 **Beautiful syntax highlighting** with `bat` 
- 📁 **Visual file browsing** with `yazi` terminal file manager
- 🚀 **One-command operations** for common Kubernetes tasks
- 💾 **Safe operations** with confirmation prompts
- 🔄 **Multi-container support** for complex pod operations
- 📊 **Real-time monitoring** capabilities
- 🎯 **Context and namespace management** made simple

## 🎬 Demo

```bash
# Interactive pod operations
$ kpod -n production
# ┌─ Select a pod ─────────────────────────────────┐
# │ nginx-deployment-7d6bf8fcb5-8wj2x  2/2  Running│
# │ redis-master-1234567890-abcde      1/1  Running│
# │ api-server-9876543210-fghij        1/1  Running│
# └─────────────────────────────────────────────────┘

# What would you like to do with nginx-deployment-7d6bf8fcb5-8wj2x?
# ┌─────────────────┐
# │ logs            │
# │ logs -f         │
# │ exec bash       │
# │ describe        │
# │ port-forward    │
# └─────────────────┘
```

## 🛠️ Available Functions

### 🚀 Core Operations
| Function | Description | Example |
|----------|-------------|---------|
| `kpod` | Interactive pod selection and operations | `kpod -n production` |
| `ksvc` | Interactive service management | `ksvc -n staging` |
| `kdep` | Interactive deployment management | `kdep` |
| `kns` | Interactive namespace operations | `kns` |

### 📁 Resource Management  
| Function | Description | Example |
|----------|-------------|---------|
| `kconfig` | ConfigMap/Secret management | `kconfig -n default` |
| `kbrowse` | Browse resources with yazi | `kbrowse -n production` |
| `klogs` | Interactive log viewer | `klogs -n system` |

### 🔍 Navigation & Search
| Function | Description | Example |
|----------|-------------|---------|
| `kctx` | Quick context switcher | `kctx` |
| `ktop` | Resource usage monitor | `ktop -n production` |
| `ksearch` | Multi-resource search | `ksearch nginx` |

### 💡 Convenience Aliases
```bash
kp   # kpod
ks   # ksvc  
kd   # kdep
kc   # kconfig
kb   # kbrowse
kl   # klogs
kt   # ktop
kx   # kctx
```

## ⚡ Quick Start

### 1. Installation
```bash
# Download the utility functions
curl -o ~/.k8s-utils.sh https://raw.githubusercontent.com/your-repo/k8s-utils.sh

# Add to your shell profile
echo 'source ~/.k8s-utils.sh' >> ~/.bashrc
source ~/.bashrc
```

### 2. Prerequisites
Make sure you have these tools installed:
- `kubectl` - Kubernetes CLI
- `fzf` - Fuzzy finder
- `bat` - Better cat with syntax highlighting  
- `yazi` - Terminal file manager

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

### 3. Start Using
```bash
# Get help
khelp

# Try some basic operations
kctx          # Switch Kubernetes contexts
kns           # Explore namespaces
kpod          # Work with pods
ktop          # Monitor resource usage
```

## 📚 Documentation

- **[INSTALL.md](INSTALL.md)** - Complete installation and setup guide
- **[EXAMPLES.md](EXAMPLES.md)** - Real-world usage scenarios and workflows

## 🎯 Real-World Examples

### Morning Health Check
```bash
# Quick cluster overview
kns                    # Browse namespaces
ktop                   # Check resource usage  
ksearch "error|fail"   # Find any issues
```

### Debugging Application Issues
```bash
kpod -n production     # Find problematic pod
# Select pod → choose "logs" for recent logs with syntax highlighting
# Or choose "exec bash" to investigate inside container
```

### Configuration Management
```bash
kbrowse -n production  # Browse all resources with yazi
kconfig -n production  # View/edit ConfigMaps and Secrets
```

### Deployment Operations
```bash
kdep -n staging        # Select deployment
# Choose "scale" to adjust replicas
# Choose "restart" to restart deployment
# Choose "rollout-status" to monitor progress
```

## 🔧 What Makes This Different

### Traditional kubectl workflow:
```bash
kubectl get pods -n production
kubectl describe pod nginx-deployment-7d6bf8fcb5-8wj2x -n production
kubectl logs nginx-deployment-7d6bf8fcb5-8wj2x -n production
```

### With k8s-utils:
```bash
kpod -n production
# Interactive selection → automatic operations → beautiful output
```

## 🎨 Features in Detail

### Interactive Selection with fzf
- **Fuzzy search** through resources
- **Live preview** of resource details
- **Multi-selection** where applicable
- **Custom key bindings** for efficiency

### Beautiful Output with bat
- **Syntax highlighting** for YAML/JSON
- **Line numbers** and **git integration**
- **Paging** with search capabilities
- **Theme support** for different preferences

### File Browsing with yazi
- **Visual navigation** through exported resources
- **File preview** capabilities
- **Quick operations** on multiple files
- **Integration** with other tools

### Smart Operations
- **Context awareness** - knows your current cluster/namespace
- **Safety checks** - confirmation prompts for destructive operations
- **Multi-container support** - handles complex pod scenarios
- **Error handling** - graceful failures with helpful messages

## 🚀 Advanced Usage

### Integration with Other Tools
```bash
# Use with tmux for monitoring multiple environments
tmux new-session -d -s k8s
tmux send-keys 'ktop -n production' Enter

# Combine with git workflows  
kbrowse -n production  # Export configs for version control
```

### Custom Workflows
```bash
# Create custom aliases for frequent operations
alias kprod='kpod -n production'
alias kstag='kpod -n staging'

# Chain operations together
kctx && kns && kpod  # Context → Namespace → Pod operations
```

## 🤝 Contributing

We welcome contributions! Here are some ways you can help:

- 🐛 **Bug reports** - Found an issue? Let us know!
- 💡 **Feature requests** - Have an idea? We'd love to hear it!
- 📖 **Documentation** - Help improve our docs
- 🔧 **Code contributions** - Submit PRs for new features or fixes

## 📋 Requirements

- **Kubernetes cluster** access with `kubectl` configured
- **Bash or Zsh** shell
- **Linux or macOS** (Windows with WSL should work)
- **Terminal** with color support

## 🔒 Security Notes

- Functions include **confirmation prompts** for destructive operations
- **No sensitive data** is logged or stored
- **Temporary files** are cleaned up automatically
- Uses **standard kubectl** authentication and authorization

## 📄 License

MIT License - feel free to use, modify, and distribute!

## 🌟 Why Use This?

✅ **Faster operations** - Interactive selection beats typing long commands  
✅ **Fewer mistakes** - Visual confirmation reduces errors  
✅ **Better understanding** - Preview windows show what you're working with  
✅ **Consistent workflow** - Same pattern for all resource types  
✅ **Learning aid** - See the actual kubectl commands being executed  
✅ **Productivity boost** - Complex operations become simple  

---

**Made with ❤️ for the Kubernetes community**

*Transform your kubectl experience from tedious to delightful!*
