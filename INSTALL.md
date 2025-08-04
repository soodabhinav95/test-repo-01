# Kubernetes Utils Setup Guide

## Prerequisites Installation

### 1. Install kubectl
```bash
# For Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### 2. Install fzf (Fuzzy Finder)
```bash
# Using package manager (Ubuntu/Debian)
sudo apt install fzf

# Using git (for latest version)
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

# Using curl
curl -fLo /tmp/fzf-install https://raw.githubusercontent.com/junegunn/fzf/master/install
bash /tmp/fzf-install
```

### 3. Install bat (Better cat)
```bash
# Ubuntu/Debian
sudo apt install bat

# If installed as 'batcat', create alias
echo 'alias bat=batcat' >> ~/.bashrc

# Or download latest release
wget https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb
sudo dpkg -i bat_0.24.0_amd64.deb
```

### 4. Install yazi (Terminal File Manager)
```bash
# Using cargo (Rust package manager)
cargo install --locked yazi-fm yazi-cli

# Or download precompiled binary
curl -fsSL https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.tar.gz | tar -xz
sudo mv yazi-x86_64-unknown-linux-gnu/yazi* /usr/local/bin/

# Verify installation
yazi --version
```

## Setup Instructions

### 1. Download and Source the Functions
```bash
# Download the k8s-utils.sh file to your preferred location
curl -o ~/.k8s-utils.sh https://raw.githubusercontent.com/your-repo/k8s-utils.sh

# Or if you have the file locally
cp k8s-utils.sh ~/.k8s-utils.sh

# Make it executable
chmod +x ~/.k8s-utils.sh
```

### 2. Add to Your Shell Profile
```bash
# For bash users
echo 'source ~/.k8s-utils.sh' >> ~/.bashrc

# For zsh users  
echo 'source ~/.k8s-utils.sh' >> ~/.zshrc

# For fish users
echo 'source ~/.k8s-utils.sh' >> ~/.config/fish/config.fish
```

### 3. Reload Your Shell
```bash
# Reload your shell configuration
source ~/.bashrc  # or ~/.zshrc
```

## Configuration

### Optional: Configure bat themes
```bash
# List available themes
bat --list-themes

# Set a preferred theme
echo 'export BAT_THEME="Dracula"' >> ~/.bashrc
# or
echo 'export BAT_THEME="GitHub"' >> ~/.bashrc
```

### Optional: Configure fzf
```bash
# Add to your shell profile for better fzf experience
export FZF_DEFAULT_OPTS='
  --height 40% 
  --layout reverse 
  --border 
  --preview-window=right:50%:wrap
  --bind="ctrl-a:select-all,ctrl-d:deselect-all"
'
```

### Optional: Configure yazi
```bash
# Create yazi config directory
mkdir -p ~/.config/yazi

# Basic yazi configuration (optional)
cat > ~/.config/yazi/yazi.toml << 'EOF'
[manager]
show_hidden = true
sort_by = "modified"
sort_reverse = true
linemode = "size"

[preview]
tab_size = 2
max_width = 600
max_height = 900
EOF
```

## Verification

Test that everything is working:

```bash
# Check if all tools are available
which kubectl fzf bat yazi

# Test the functions are loaded
khelp

# Test a simple function (if you have a k8s cluster)
kctx
```

## Troubleshooting

### Common Issues

1. **"command not found" errors**
   - Make sure all prerequisites are installed
   - Check that the tools are in your PATH
   - Restart your terminal session

2. **fzf not working properly**
   - Install fzf shell integration: `~/.fzf/install`
   - Make sure fzf is in your PATH

3. **bat showing as "batcat"**
   - Create an alias: `alias bat=batcat`
   - Or create a symlink: `sudo ln -s /usr/bin/batcat /usr/local/bin/bat`

4. **Permission denied errors**
   - Make sure the script is executable: `chmod +x ~/.k8s-utils.sh`
   - Check kubectl permissions and cluster access

5. **Functions not loading**
   - Verify the script is sourced: `source ~/.k8s-utils.sh`
   - Check for syntax errors: `bash -n ~/.k8s-utils.sh`

## Kubernetes Cluster Setup

If you don't have a Kubernetes cluster, you can use:

### Minikube (Local development)
```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start

# Enable metrics server (for ktop function)
minikube addons enable metrics-server
```

### Kind (Kubernetes in Docker)
```bash
# Install kind
go install sigs.k8s.io/kind@v0.20.0

# Create cluster
kind create cluster

# Load cluster config
export KUBECONFIG="$(kind get kubeconfig-path)"
```

### k3s (Lightweight Kubernetes)
```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

## Advanced Configuration

### Custom Key Bindings for fzf
```bash
# Add custom fzf bindings
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
  --bind='ctrl-y:execute-silent(echo {} | xclip -selection clipboard)'
  --bind='ctrl-e:execute(echo {} | xargs -o vim)'
  --bind='ctrl-o:execute(echo {} | xargs -o code)'
"
```

### Integration with Other Tools

#### Helm Integration
```bash
# Add to k8s-utils.sh for Helm support
khelm() {
    local release=$(helm list -o json | jq -r '.[].name' | \
        fzf --header="Select Helm release" \
            --preview="helm status {}")
    
    if [[ -n "$release" ]]; then
        local action=$(echo -e "status\nvalues\nhistory\nrollback\nuninstall" | \
            fzf --header="Action for $release")
        
        case "$action" in
            "status") helm status "$release" | bat --language=yaml ;;
            "values") helm get values "$release" | bat --language=yaml ;;
            "history") helm history "$release" ;;
            "rollback") 
                local revision=$(helm history "$release" | tail -n +2 | \
                    fzf --header="Select revision to rollback to" | awk '{print $1}')
                if [[ -n "$revision" ]]; then
                    helm rollback "$release" "$revision"
                fi
                ;;
            "uninstall")
                echo "Are you sure you want to uninstall $release? (y/N)"
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    helm uninstall "$release"
                fi
                ;;
        esac
    fi
}
```

#### Kubectl Plugins
```bash
# Install krew (kubectl plugin manager)
curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_amd64.tar.gz"
tar zxvf krew-linux_amd64.tar.gz
./krew-linux_amd64 install krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Useful plugins
kubectl krew install ctx ns tree top
```

That's it! You should now have a powerful set of Kubernetes utilities that make daily operations much more efficient and user-friendly.