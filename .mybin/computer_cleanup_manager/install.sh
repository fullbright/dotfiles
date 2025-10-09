#!/bin/bash
#
# install.sh - Installation script for Mac cleanup tools
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
BOLD=$'\e[1m'
NC=$'\e[0m'

echo "${BOLD}${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Mac Cleanup & GitHub Organization Tool                 ║
║   Installation Script                                     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo "${NC}"

log_info() {
    echo "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo "${RED}[ERROR]${NC} $*"
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Install prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    # Check for git
    if ! command_exists git; then
        missing+=("git")
    else
        log_success "Git is installed: $(git --version)"
    fi
    
    # Check for GitHub CLI
    if ! command_exists gh; then
        missing+=("gh")
    else
        log_success "GitHub CLI is installed: $(gh --version | head -n1)"
        
        # Check if authenticated
        if ! gh auth status &>/dev/null; then
            log_warn "GitHub CLI is not authenticated"
            log_info "Run: gh auth login"
        else
            log_success "GitHub CLI is authenticated"
        fi
    fi
    
    # Check for jq
    if ! command_exists jq; then
        missing+=("jq")
    else
        log_success "jq is installed: $(jq --version)"
    fi
    
    # Optional: GPG
    if ! command_exists gpg; then
        log_warn "GPG not found (optional, for file encryption)"
    else
        log_success "GPG is installed: $(gpg --version | head -n1)"
    fi
    
    # Optional: rsync
    if ! command_exists rsync; then
        log_warn "rsync not found (optional, for better file copying)"
    else
        log_success "rsync is installed"
    fi
    
    # Report missing dependencies
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        log_error "Missing required dependencies: ${missing[*]}"
        echo ""
        
        if [[ "$(uname)" == "Darwin" ]]; then
            log_info "On macOS, you can install missing dependencies with Homebrew:"
            echo ""
            echo "  ${BOLD}brew install ${missing[*]}${NC}"
            echo ""
        elif [[ "$(uname)" == "Linux" ]]; then
            log_info "On Linux, you can install missing dependencies with your package manager:"
            echo ""
            echo "  ${BOLD}# Debian/Ubuntu${NC}"
            echo "  sudo apt-get install ${missing[*]}"
            echo ""
            echo "  ${BOLD}# Fedora/RHEL${NC}"
            echo "  sudo dnf install ${missing[*]}"
            echo ""
        fi
        
        return 1
    fi
    
    log_success "All required dependencies are installed"
    return 0
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p "$SCRIPT_DIR/lib"
    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$HOME/.cleanup_state"
    mkdir -p "$HOME/.cleanup_backups"
    mkdir -p "$HOME/dev_completed"
    
    log_success "Directories created"
}

# Set up configuration
setup_configuration() {
    log_info "Setting up configuration..."
    
    local config_file="$SCRIPT_DIR/.cleanup.config"
    local user_config="$HOME/.cleanup.config"
    
    if [[ -f "$user_config" ]]; then
        log_warn "Configuration already exists: $user_config"
        echo -n "Overwrite? (y/n): "
        read -r response
        if [[ "$response" != "y" ]]; then
            log_info "Keeping existing configuration"
            return 0
        fi
    fi
    
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$user_config"
        log_success "Configuration copied to: $user_config"
        
        log_info "You can edit the configuration file to customize settings"
        echo "  ${BOLD}$user_config${NC}"
    else
        log_warn "Default configuration not found, creating minimal config"
        
        cat > "$user_config" << 'EOF'
# Minimal cleanup configuration
DEFAULT_GITHUB_OWNERS="fullbright,BrightSoftwares"
MY_GITHUB_ACCOUNTS=("fullbright" "BrightSoftwares")
COMPLETED_FOLDER="$HOME/dev_completed"
DOTFILES_REPO="$HOME/dotfiles"
EOF
        
        log_success "Minimal configuration created: $user_config"
    fi
}

# Make scripts executable
make_executable() {
    log_info "Making scripts executable..."
    
    chmod +x "$SCRIPT_DIR/cleanup_manager.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/version_dotfiles.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR"/lib/*.sh 2>/dev/null || true
    
    log_success "Scripts are now executable"
}

# Create convenience symlinks
create_symlinks() {
    log_info "Creating convenience symlinks..."
    
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    # Check if bin_dir is in PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        log_warn "$bin_dir is not in your PATH"
        log_info "Add this to your ~/.bashrc or ~/.zshrc:"
        echo "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi
    
    # Create symlinks
    ln -sf "$SCRIPT_DIR/cleanup_manager.sh" "$bin_dir/cleanup-manager" 2>/dev/null || true
    ln -sf "$SCRIPT_DIR/version_dotfiles.sh" "$bin_dir/version-dotfiles" 2>/dev/null || true
    
    log_success "Symlinks created in: $bin_dir"
    log_info "You can now run:"
    echo "  ${BOLD}cleanup-manager ~/dev${NC}"
    echo "  ${BOLD}version-dotfiles --help${NC}"
}

# Run tests
run_tests() {
    log_info "Running basic tests..."
    
    # Test lib loading
    if source "$SCRIPT_DIR/lib/core.sh" 2>/dev/null; then
        log_success "Core library loads successfully"
    else
        log_error "Failed to load core library"
        return 1
    fi
    
    # Test configuration
    if [[ -f "$HOME/.cleanup.config" ]]; then
        if source "$HOME/.cleanup.config" 2>/dev/null; then
            log_success "Configuration file is valid"
        else
            log_error "Configuration file has errors"
            return 1
        fi
    fi
    
    log_success "All tests passed"
}

# Show usage information
show_usage() {
    echo ""
    log_info "Installation complete! Here's how to get started:"
    echo ""
    echo "${BOLD}Basic Usage:${NC}"
    echo "  ${BLUE}cleanup-manager ~/dev${NC}"
    echo "    Process and organize folders in ~/dev"
    echo ""
    echo "  ${BLUE}cleanup-manager --dry-run ~/dev${NC}"
    echo "    Preview what would be done without making changes"
    echo ""
    echo "  ${BLUE}cleanup-manager --help${NC}"
    echo "    Show all available options"
    echo ""
    echo "${BOLD}Dotfiles Management:${NC}"
    echo "  ${BLUE}version-dotfiles --init${NC}"
    echo "    Initialize dotfiles repository"
    echo ""
    echo "  ${BLUE}version-dotfiles --add ~/.config/nvim${NC}"
    echo "    Add a folder to dotfiles"
    echo ""
    echo "  ${BLUE}version-dotfiles --sync${NC}"
    echo "    Sync changes to repository"
    echo ""
    echo "${BOLD}Configuration:${NC}"
    echo "  Edit: ${BOLD}$HOME/.cleanup.config${NC}"
    echo ""
    echo "${BOLD}Documentation:${NC}"
    echo "  See README.md for detailed information"
    echo ""
}

# Main installation
main() {
    echo ""
    log_info "Starting installation..."
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        echo ""
        log_info "Please install missing dependencies and run this script again"
        exit 1
    fi
    
    echo ""
    
    # Create directories
    create_directories
    
    echo ""
    
    # Set up configuration
    setup_configuration
    
    echo ""
    
    # Make scripts executable
    make_executable
    
    echo ""
    
    # Create symlinks
    create_symlinks
    
    echo ""
    
    # Run tests
    if ! run_tests; then
        log_error "Tests failed"
        exit 1
    fi
    
    echo ""
    log_success "${BOLD}Installation completed successfully!${NC}"
    echo ""
    
    # Show usage
    show_usage
}

main "$@"