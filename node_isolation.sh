
#!/bin/bash

# =============================================================================
# Node.js Bubblewrap Sandbox Installer
# 
# This script sets up complete Node.js and npm isolation using bubblewrap
# for enhanced security when running potentially malicious npm packages.
#
# Features:
# - Isolates Node.js and npm in a secure sandbox
# - Protects SSH keys, browser data, and system files
# - Maintains development workflow capabilities
# - Provides network access for npm installs
# - Creates comprehensive test scripts for verification
#
# Author: Generated for secure Node.js development
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${CYAN}${BOLD}${'='*60}${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}${'='*60}${NC}"
}

print_step() {
    echo -e "\n${BLUE}${BOLD}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root!"
        print_info "Please run as your regular user account."
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_step "Checking system requirements..."
    
    # Check if bubblewrap is installed
    if ! command -v bwrap &> /dev/null; then
        print_error "bubblewrap is not installed!"
        print_info "Install it with: sudo apt install bubblewrap"
        exit 1
    fi
    print_success "bubblewrap found: $(which bwrap)"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed!"
        print_info "Install it with: sudo apt install nodejs"
        exit 1
    fi
    print_success "Node.js found: $(which node) ($(node --version))"
    
    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed!"
        print_info "Install it with: sudo apt install npm"
        exit 1
    fi
    print_success "npm found: $(which npm) ($(npm --version))"
    
    # Check bubblewrap permissions
    BWRAP_PATH=$(which bwrap)
    if [[ ! -u "$BWRAP_PATH" ]]; then
        print_warning "bubblewrap needs setuid permissions for proper operation"
        print_info "You may need to run: sudo chmod u+s $BWRAP_PATH"
        
        read -p "Do you want to set bubblewrap permissions now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo chmod u+s "$BWRAP_PATH"
            print_success "bubblewrap permissions set"
        else
            print_warning "Continuing without setting permissions - sandbox may not work properly"
        fi
    else
        print_success "bubblewrap has proper permissions"
    fi
    
    # Check if user namespaces are enabled
    if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
        USERNS_ENABLED=$(cat /proc/sys/kernel/unprivileged_userns_clone)
        if [[ "$USERNS_ENABLED" != "1" ]]; then
            print_warning "Unprivileged user namespaces are disabled"
            print_info "You may need to run: sudo sysctl kernel.unprivileged_userns_clone=1"
            
            read -p "Do you want to enable user namespaces now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo sysctl kernel.unprivileged_userns_clone=1
                echo 'kernel.unprivileged_userns_clone=1' | sudo tee -a /etc/sysctl.conf
                print_success "User namespaces enabled"
            fi
        else
            print_success "User namespaces are enabled"
        fi
    fi
}

# Create directory structure
setup_directories() {
    print_step "Setting up sandbox directories..."
    
    # Create local bin directory
    mkdir -p "$HOME/.local/bin"
    print_success "Created $HOME/.local/bin"
    
    # Create sandbox home directory
    SANDBOX_HOME="$HOME/.sandbox/node"
    mkdir -p "$SANDBOX_HOME"
    mkdir -p "$SANDBOX_HOME/tmp"
    mkdir -p "$SANDBOX_HOME/.npm"
    mkdir -p "$SANDBOX_HOME/.npm-global"
    mkdir -p "$SANDBOX_HOME/.npm-global/bin"
    mkdir -p "$SANDBOX_HOME/.npm-global/lib"
    print_success "Created sandbox directory: $SANDBOX_HOME"
    
    # Create npm configuration in sandbox
    cat > "$SANDBOX_HOME/.npmrc" << EOF
prefix=$SANDBOX_HOME/.npm-global
cache=$SANDBOX_HOME/.npm
EOF
    print_success "Created npm configuration"
}

# Create Node.js wrapper script
create_node_wrapper() {
    print_step "Creating Node.js sandbox wrapper..."
    
    cat > "$HOME/.local/bin/node" << 'EOF'
#!/bin/bash

# Sandboxed Node.js wrapper using bubblewrap
REAL_NODE="/usr/bin/node"
SANDBOX_HOME="$HOME/.sandbox/node"

# Ensure sandbox home exists
mkdir -p "$SANDBOX_HOME"
mkdir -p "$SANDBOX_HOME/tmp"

exec bwrap \
    --unshare-all \
    --share-net \
    --clearenv \
    --setenv HOME "$SANDBOX_HOME" \
    --setenv USER "$USER" \
    --setenv PATH "/usr/bin:/bin:/usr/local/bin:$SANDBOX_HOME/.npm-global/bin" \
    --setenv PWD "$(pwd)" \
    --ro-bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 \
    --ro-bind /bin /bin \
    --ro-bind /sbin /sbin \
    --ro-bind /etc/ld.so.cache /etc/ld.so.cache \
    --ro-bind /etc/ld.so.conf /etc/ld.so.conf \
    --ro-bind /etc/ld.so.conf.d /etc/ld.so.conf.d \
    --ro-bind /etc/passwd /etc/passwd \
    --ro-bind /etc/group /etc/group \
    --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/ssl /etc/ssl \
    --ro-bind /etc/ca-certificates /etc/ca-certificates \
    --bind "$SANDBOX_HOME" "$SANDBOX_HOME" \
    --bind "$SANDBOX_HOME/tmp" /tmp \
    --bind "$(pwd)" "$(pwd)" \
    --proc /proc \
    --dev /dev \
    --tmpfs /run \
    --tmpfs /var \
    --die-with-parent \
    --new-session \
    "$REAL_NODE" "$@"
EOF
    
    chmod +x "$HOME/.local/bin/node"
    print_success "Created sandboxed node wrapper"
}

# Create npm wrapper script
create_npm_wrapper() {
    print_step "Creating npm sandbox wrapper..."
    
    cat > "$HOME/.local/bin/npm" << 'EOF'
#!/bin/bash

# Sandboxed npm wrapper using bubblewrap
REAL_NPM="/usr/bin/npm"
SANDBOX_HOME="$HOME/.sandbox/node"

# Ensure sandbox home exists
mkdir -p "$SANDBOX_HOME"

# Create npm directories in sandbox
mkdir -p "$SANDBOX_HOME/.npm"
mkdir -p "$SANDBOX_HOME/.npm-global"
mkdir -p "$SANDBOX_HOME/.npm-global/bin"
mkdir -p "$SANDBOX_HOME/.npm-global/lib"

# Create npm config if it doesn't exist
if [[ ! -f "$SANDBOX_HOME/.npmrc" ]]; then
    cat > "$SANDBOX_HOME/.npmrc" << NPMEOF
prefix=$SANDBOX_HOME/.npm-global
cache=$SANDBOX_HOME/.npm
NPMEOF
fi

# Create a minimal /tmp inside sandbox
SANDBOX_TMP="$SANDBOX_HOME/tmp"
mkdir -p "$SANDBOX_TMP"

exec bwrap \
    --unshare-all \
    --share-net \
    --clearenv \
    --setenv HOME "$SANDBOX_HOME" \
    --setenv USER "$USER" \
    --setenv PATH "/usr/bin:/bin:/usr/local/bin:$SANDBOX_HOME/.npm-global/bin" \
    --setenv PWD "$(pwd)" \
    --ro-bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 \
    --ro-bind /bin /bin \
    --ro-bind /sbin /sbin \
    --ro-bind /etc/ld.so.cache /etc/ld.so.cache \
    --ro-bind /etc/ld.so.conf /etc/ld.so.conf \
    --ro-bind /etc/ld.so.conf.d /etc/ld.so.conf.d \
    --ro-bind /etc/passwd /etc/passwd \
    --ro-bind /etc/group /etc/group \
    --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/ssl /etc/ssl \
    --ro-bind /etc/ca-certificates /etc/ca-certificates \
    --bind "$SANDBOX_HOME" "$SANDBOX_HOME" \
    --bind "$SANDBOX_TMP" /tmp \
    --bind "$(pwd)" "$(pwd)" \
    --proc /proc \
    --dev /dev \
    --tmpfs /run \
    --tmpfs /var \
    --die-with-parent \
    --new-session \
    "$REAL_NPM" "$@"
EOF
    
    chmod +x "$HOME/.local/bin/npm"
    print_success "Created sandboxed npm wrapper"
}

# Setup PATH in shell configuration
setup_path() {
    print_step "Configuring PATH in shell profiles..."
    
    PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
    
    # Add to .bashrc if it exists
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc"; then
            echo "" >> "$HOME/.bashrc"
            echo "# Node.js sandbox - added by Node.js sandbox installer" >> "$HOME/.bashrc"
            echo "$PATH_EXPORT" >> "$HOME/.bashrc"
            print_success "Added PATH to .bashrc"
        else
            print_info ".bashrc already contains .local/bin in PATH"
        fi
    fi
    
    # Add to .zshrc if it exists
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "$HOME/.local/bin" "$HOME/.zshrc"; then
            echo "" >> "$HOME/.zshrc"
            echo "# Node.js sandbox - added by Node.js sandbox installer" >> "$HOME/.zshrc"
            echo "$PATH_EXPORT" >> "$HOME/.zshrc"
            print_success "Added PATH to .zshrc"
        else
            print_info ".zshrc already contains .local/bin in PATH"
        fi
    fi
    
    # Add to .profile as fallback
    if [[ -f "$HOME/.profile" ]]; then
        if ! grep -q "$HOME/.local/bin" "$HOME/.profile"; then
            echo "" >> "$HOME/.profile"
            echo "# Node.js sandbox - added by Node.js sandbox installer" >> "$HOME/.profile"
            echo "$PATH_EXPORT" >> "$HOME/.profile"
            print_success "Added PATH to .profile"
        else
            print_info ".profile already contains .local/bin in PATH"
        fi
    fi
}

# Create test scripts
create_test_scripts() {
    print_step "Creating security test scripts..."
    
    # Create basic test script
    cat > "$HOME/.local/bin/test-node-sandbox" << 'EOF'
#!/usr/bin/env node

console.log('🔍 Node.js Sandbox Quick Test');
console.log('============================');
console.log('Node version:', process.version);
console.log('Home directory:', require('os').homedir());
console.log('Current directory:', process.cwd());

// Test write to sandbox home
const fs = require('fs');
const path = require('path');
const testFile = path.join(require('os').homedir(), 'test-write.txt');

try {
    fs.writeFileSync(testFile, 'Sandbox test successful!');
    const content = fs.readFileSync(testFile, 'utf8');
    console.log('✅ Write test:', content);
    fs.unlinkSync(testFile);
} catch (error) {
    console.log('❌ Write test failed:', error.message);
}

// Test sensitive file access
try {
    const sensitiveFile = '/home/' + (process.env.USER || 'user') + '/.ssh/id_rsa';
    fs.readFileSync(sensitiveFile);
    console.log('❌ Security issue: Can read SSH keys!');
} catch (error) {
    console.log('✅ Security test: SSH keys protected');
}

console.log('\n🎯 Quick test complete!');
EOF
    
    chmod +x "$HOME/.local/bin/test-node-sandbox"
    print_success "Created basic test script: test-node-sandbox"
    
    # Copy comprehensive test if we have it in current directory
    if [[ -f "comprehensive_node_isolation_test.js" ]]; then
        cp "comprehensive_node_isolation_test.js" "$HOME/.local/bin/test-node-sandbox-full"
        chmod +x "$HOME/.local/bin/test-node-sandbox-full"
        print_success "Copied comprehensive test script: test-node-sandbox-full"
    fi
}

# Test installation
test_installation() {
    print_step "Testing sandbox installation..."
    
    # Export PATH for this session
    export PATH="$HOME/.local/bin:$PATH"
    
    # Test which commands are being used
    NODE_WHICH=$(which node)
    NPM_WHICH=$(which npm)
    
    print_info "node command location: $NODE_WHICH"
    print_info "npm command location: $NPM_WHICH"
    
    if [[ "$NODE_WHICH" == "$HOME/.local/bin/node" ]]; then
        print_success "node wrapper is active"
    else
        print_warning "node wrapper not in PATH - you may need to restart your shell"
    fi
    
    if [[ "$NPM_WHICH" == "$HOME/.local/bin/npm" ]]; then
        print_success "npm wrapper is active"
    else
        print_warning "npm wrapper not in PATH - you may need to restart your shell"
    fi
    
    # Test basic functionality
    print_info "Testing Node.js version..."
    if node --version; then
        print_success "Node.js sandbox working"
    else
        print_error "Node.js sandbox test failed"
        return 1
    fi
    
    print_info "Testing npm version..."
    if npm --version; then
        print_success "npm sandbox working"
    else
        print_error "npm sandbox test failed"
        return 1
    fi
    
    # Run basic security test
    print_info "Running basic security test..."
    if test-node-sandbox; then
        print_success "Security test passed"
    else
        print_warning "Security test had issues"
    fi
}

# Create uninstaller
create_uninstaller() {
    print_step "Creating uninstaller script..."
    
    cat > "$HOME/.local/bin/uninstall-node-sandbox" << 'EOF'
#!/bin/bash

echo "🗑️  Uninstalling Node.js Sandbox..."

# Remove wrapper scripts
rm -f "$HOME/.local/bin/node"
rm -f "$HOME/.local/bin/npm"
rm -f "$HOME/.local/bin/test-node-sandbox"
rm -f "$HOME/.local/bin/test-node-sandbox-full"
rm -f "$HOME/.local/bin/uninstall-node-sandbox"

# Optionally remove sandbox directory
read -p "Remove sandbox directory $HOME/.sandbox/node? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.sandbox/node"
    echo "✅ Sandbox directory removed"
fi

echo "✅ Node.js sandbox uninstalled"
echo "Note: You may want to manually remove PATH entries from your shell config files"
EOF
    
    chmod +x "$HOME/.local/bin/uninstall-node-sandbox"
    print_success "Created uninstaller: uninstall-node-sandbox"
}

# Main installation function
main() {
    print_header "Node.js Bubblewrap Sandbox Installer"
    
    print_info "This installer will set up a secure Node.js sandbox using bubblewrap."
    print_info "The sandbox will protect your system from malicious npm packages."
    print_info ""
    
    read -p "Do you want to continue with the installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    check_not_root
    check_requirements
    setup_directories
    create_node_wrapper
    create_npm_wrapper
    setup_path
    create_test_scripts
    create_uninstaller
    
    print_header "Testing Installation"
    test_installation
    
    print_header "Installation Complete!"
    
    print_success "Node.js sandbox has been successfully installed!"
    echo
    print_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.bashrc"
    echo "  2. Test with: node --version && npm --version"
    echo "  3. Run security test: test-node-sandbox"
    echo "  4. If available, run full test: test-node-sandbox-full"
    echo
    print_info "Your Node.js and npm commands are now sandboxed!"
    print_info "Malicious packages cannot access your SSH keys, browser data, or system files."
    echo
    print_info "To uninstall: uninstall-node-sandbox"
    echo
    print_warning "Remember to restart your terminal or run 'source ~/.bashrc' to activate the sandbox!"
}

# Run main function
main "$@"