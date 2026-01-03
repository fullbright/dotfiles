#!/usr/bin/env bash
#
# Cross-Platform Dotfiles Installation Script
# Supports: macOS, Linux, Windows (via WSL or Git Bash)
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/fullbright/dotfiles/main/install.sh)
#   # or
#   git clone --bare https://github.com/fullbright/dotfiles.git $HOME/.dotfiles
#   ./install.sh
#
# Author: Kekeli Afanou (Sergio)
# Repository: https://github.com/fullbright/dotfiles

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOTFILES_REPO="https://github.com/fullbright/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
DOTFILES_BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d_%H%M%S)"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)    OS="macos" ;;
        Linux*)
            if grep -q Microsoft /proc/version 2>/dev/null; then
                OS="wsl"
            else
                OS="linux"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
        *)          OS="unknown" ;;
    esac
    echo "$OS"
}

# Detect shell
detect_shell() {
    case "$SHELL" in
        */zsh)  echo "zsh" ;;
        */bash) echo "bash" ;;
        */fish) echo "fish" ;;
        *)      echo "bash" ;;
    esac
}

# Setup dotfiles alias function
setup_dotfiles_alias() {
    local shell_type=$1
    local shell_rc

    case "$shell_type" in
        zsh)  shell_rc="$HOME/.zshrc" ;;
        bash) shell_rc="$HOME/.bashrc" ;;
        fish) shell_rc="$HOME/.config/fish/config.fish" ;;
    esac

    log_info "Setting up 'dotfiles' alias in $shell_rc..."

    # Check if alias already exists
    if grep -q "alias dotfiles=" "$shell_rc" 2>/dev/null; then
        log_warn "Dotfiles alias already exists in $shell_rc"
        return 0
    fi

    # Add the alias
    cat >> "$shell_rc" << 'DOTFILES_ALIAS'

# Dotfiles management using git bare repository
# See: https://www.atlassian.com/git/tutorials/dotfiles
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# Hide untracked files by default (cleaner status output)
# Run once: dotfiles config --local status.showUntrackedFiles no
DOTFILES_ALIAS

    log_success "Added dotfiles alias to $shell_rc"
}

# Setup shell completion for 'dotfiles' command
setup_completion() {
    local shell_type=$1

    log_info "Setting up shell completion for 'dotfiles' command..."

    case "$shell_type" in
        zsh)
            # Create zsh completion directory if it doesn't exist
            mkdir -p "$HOME/.zsh/completions"

            # Create completion file
            cat > "$HOME/.zsh/completions/_dotfiles" << 'ZSH_COMPLETION'
#compdef dotfiles

# Completion for dotfiles command (git bare repository wrapper)
# Uses git completion with custom git-dir and work-tree

_dotfiles() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Get git completions
    local git_path="/usr/bin/git"
    local git_dir="$HOME/.dotfiles"
    local work_tree="$HOME"

    # Use git completion
    _arguments -C \
        '*::git command:->command'

    case "$state" in
        command)
            # Forward to git completion
            GIT_DIR="$git_dir" GIT_WORK_TREE="$work_tree" _git
            ;;
    esac
}

_dotfiles "$@"
ZSH_COMPLETION

            # Add completion path to .zshrc if not present
            if ! grep -q 'fpath=.*\.zsh/completions' "$HOME/.zshrc" 2>/dev/null; then
                echo 'fpath=($HOME/.zsh/completions $fpath)' >> "$HOME/.zshrc"
                echo 'autoload -Uz compinit && compinit' >> "$HOME/.zshrc"
            fi
            ;;

        bash)
            # Create bash completion directory
            mkdir -p "$HOME/.bash_completion.d"

            # Create completion file
            cat > "$HOME/.bash_completion.d/dotfiles" << 'BASH_COMPLETION'
# Bash completion for dotfiles command (git bare repository wrapper)

_dotfiles_completion() {
    local cur prev words cword
    _init_completion || return

    # Use git's completion with custom paths
    GIT_DIR="$HOME/.dotfiles" GIT_WORK_TREE="$HOME" __git_wrap__git_main
}

# Register completion
complete -o bashdefault -o default -o nospace -F _dotfiles_completion dotfiles
BASH_COMPLETION

            # Source completion in .bashrc if not present
            if ! grep -q 'bash_completion.d/dotfiles' "$HOME/.bashrc" 2>/dev/null; then
                echo '[[ -f "$HOME/.bash_completion.d/dotfiles" ]] && source "$HOME/.bash_completion.d/dotfiles"' >> "$HOME/.bashrc"
            fi
            ;;

        fish)
            # Create fish completion directory
            mkdir -p "$HOME/.config/fish/completions"

            # Create completion file
            cat > "$HOME/.config/fish/completions/dotfiles.fish" << 'FISH_COMPLETION'
# Fish completion for dotfiles command (git bare repository wrapper)

function __fish_dotfiles_needs_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

# Inherit git completions
complete -c dotfiles -w git
FISH_COMPLETION
            ;;
    esac

    log_success "Shell completion configured for $shell_type"
}

# Clone dotfiles as bare repository
clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warn "Dotfiles directory already exists at $DOTFILES_DIR"
        read -p "Do you want to backup and replace it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mv "$DOTFILES_DIR" "$DOTFILES_BACKUP"
            log_info "Backed up existing dotfiles to $DOTFILES_BACKUP"
        else
            log_error "Installation cancelled"
            exit 1
        fi
    fi

    log_info "Cloning dotfiles repository as bare repo..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    log_success "Cloned dotfiles to $DOTFILES_DIR"
}

# Checkout dotfiles to home directory
checkout_dotfiles() {
    log_info "Checking out dotfiles to home directory..."

    # Define the dotfiles function for this script
    dotfiles() {
        /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
    }

    # Try to checkout
    if ! dotfiles checkout 2>/dev/null; then
        log_warn "Some files already exist. Backing them up..."

        # Get list of conflicting files
        local conflicts
        conflicts=$(dotfiles checkout 2>&1 | grep -E "^\s+" | awk '{print $1}')

        # Backup conflicting files
        mkdir -p "$DOTFILES_BACKUP"
        for file in $conflicts; do
            local dir=$(dirname "$file")
            mkdir -p "$DOTFILES_BACKUP/$dir"
            mv "$HOME/$file" "$DOTFILES_BACKUP/$file" 2>/dev/null || true
            log_info "Backed up: $file"
        done

        # Try checkout again
        dotfiles checkout
    fi

    # Configure to hide untracked files
    dotfiles config --local status.showUntrackedFiles no

    log_success "Dotfiles checked out successfully!"
}

# Fixed clone_dotfiles function
clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warn "Dotfiles directory already exists at $DOTFILES_DIR"
        read -p "Do you want to backup and replace it? (y/n) " -n 1 -r </dev/tty
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Backup the bare repository
            mv "$DOTFILES_DIR" "$DOTFILES_BACKUP"
            log_info "Backed up existing dotfiles repository to $DOTFILES_BACKUP"
            
            # IMPORTANT: Also backup any tracked files that might conflict
            # Get list of tracked files from the backed-up repo
            local tracked_files
            tracked_files=$(/usr/bin/git --git-dir="$DOTFILES_BACKUP" --work-tree="$HOME" ls-tree -r HEAD --name-only 2>/dev/null || true)
            
            if [[ -n "$tracked_files" ]]; then
                log_info "Backing up currently tracked dotfiles..."
                local backup_dir="${DOTFILES_BACKUP}-files"
                mkdir -p "$backup_dir"
                
                while IFS= read -r file; do
                    if [[ -f "$HOME/$file" ]] || [[ -L "$HOME/$file" ]]; then
                        local dir=$(dirname "$file")
                        mkdir -p "$backup_dir/$dir"
                        cp -a "$HOME/$file" "$backup_dir/$file" 2>/dev/null || true
                        rm -f "$HOME/$file"
                        log_info "Backed up and removed: $file"
                    fi
                done <<< "$tracked_files"
                
                log_success "Tracked files backed up to $backup_dir"
            fi
        else
            log_error "Installation cancelled"
            exit 1
        fi
    fi

    log_info "Cloning dotfiles repository as bare repo..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    log_success "Cloned dotfiles to $DOTFILES_DIR"
}

# Alternative simpler approach - just force checkout
checkout_dotfiles_force() {
    log_info "Checking out dotfiles to home directory..."

    # Define the dotfiles function for this script
    dotfiles() {
        /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
    }

    # Get list of files that will conflict
    local conflicts
    conflicts=$(dotfiles checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' || true)

    if [[ -n "$conflicts" ]]; then
        log_warn "The following files will be overwritten:"
        echo "$conflicts" | head -20
        if [[ $(echo "$conflicts" | wc -l) -gt 20 ]]; then
            echo "... and $(( $(echo "$conflicts" | wc -l) - 20 )) more files"
        fi
        echo
        
        read -p "Backup these files and continue? (y/n) " -n 1 -r </dev/tty
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Checkout cancelled"
            exit 1
        fi

        # Backup conflicting files
        mkdir -p "$DOTFILES_BACKUP"
        while IFS= read -r file; do
            if [[ -f "$HOME/$file" ]] || [[ -L "$HOME/$file" ]]; then
                local dir=$(dirname "$file")
                mkdir -p "$DOTFILES_BACKUP/$dir"
                mv "$HOME/$file" "$DOTFILES_BACKUP/$file" 2>/dev/null || true
                log_info "Backed up: $file"
            fi
        done <<< "$conflicts"

        # Try checkout again
        if ! dotfiles checkout 2>/dev/null; then
            # If still failing, force it
            log_warn "Forcing checkout..."
            dotfiles checkout -f
        fi
    else
        # No conflicts, just checkout
        dotfiles checkout
    fi

    # Configure to hide untracked files
    dotfiles config --local status.showUntrackedFiles no

    log_success "Dotfiles checked out successfully!"
}

# Complete fixed version combining both
clone_and_checkout_fixed() {
    # Handle existing dotfiles directory
    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warn "Dotfiles directory already exists at $DOTFILES_DIR"
        read -p "Do you want to start fresh? This will backup and remove existing dotfiles. (y/n) " -n 1 -r </dev/tty
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Create backup directory
            local backup_base="${DOTFILES_BACKUP}-complete"
            mkdir -p "$backup_base"
            
            # Backup the bare repository
            if [[ -d "$DOTFILES_DIR" ]]; then
                cp -R "$DOTFILES_DIR" "$backup_base/.dotfiles"
                log_info "Backed up repository to $backup_base/.dotfiles"
            fi
            
            # Get list of tracked files and back them up
            local tracked_files
            tracked_files=$(/usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" ls-tree -r HEAD --name-only 2>/dev/null || true)
            
            if [[ -n "$tracked_files" ]]; then
                log_info "Backing up tracked files..."
                while IFS= read -r file; do
                    if [[ -e "$HOME/$file" ]]; then
                        local dir=$(dirname "$file")
                        mkdir -p "$backup_base/home/$dir"
                        cp -a "$HOME/$file" "$backup_base/home/$file" 2>/dev/null || true
                        rm -f "$HOME/$file"
                    fi
                done <<< "$tracked_files"
            fi
            
            # Remove old repo
            rm -rf "$DOTFILES_DIR"
            log_success "Cleaned up old dotfiles. Backup at: $backup_base"
        else
            log_error "Installation cancelled"
            exit 1
        fi
    fi

    # Clone fresh
    log_info "Cloning dotfiles repository as bare repo..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    log_success "Cloned dotfiles to $DOTFILES_DIR"

    # Checkout
    log_info "Checking out dotfiles to home directory..."
    dotfiles() {
        /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
    }
    
    if ! dotfiles checkout 2>/dev/null; then
        log_warn "Some files exist and would be overwritten. Using force checkout..."
        dotfiles checkout -f
    fi
    
    dotfiles config --local status.showUntrackedFiles no
    log_success "Dotfiles checked out successfully!"
}

# Install platform-specific packages
install_packages() {
    local os=$1

    log_info "Installing packages for $os..."

    case "$os" in
        macos)
            # Check for Homebrew
            if ! command -v brew &>/dev/null; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi

            # Run Corey Schafer's install script if available
            if [[ -f "$HOME/.config/macos/corey_schafer_reference/install.sh" ]]; then
                read -p "Run Homebrew setup from Corey Schafer reference? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    bash "$HOME/.config/macos/corey_schafer_reference/install.sh"
                fi
            fi
            ;;

        linux|wsl)
            if [[ -f "$HOME/.config/linux/install_laptop_tools.sh" ]]; then
                read -p "Run Linux laptop tools installation? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    bash "$HOME/.config/linux/install_laptop_tools.sh"
                fi
            fi
            ;;

        windows)
            log_info "Windows detected. Available package managers:"
            echo "  1. winget (built-in Windows 11+)"
            echo "  2. chocolatey (https://chocolatey.org)"
            echo "  3. scoop (https://scoop.sh)"

            read -p "Which package manager to use? (1/2/3/skip) " -n 1 -r
            echo

            case $REPLY in
                1)
                    if command -v winget &>/dev/null; then
                        log_info "Using winget..."
                        # Add winget packages here
                    else
                        log_warn "winget not found. Install Windows App Installer from Microsoft Store."
                    fi
                    ;;
                2)
                    if command -v choco &>/dev/null; then
                        log_info "Using Chocolatey..."
                    else
                        log_info "Installing Chocolatey..."
                        powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
                    fi
                    ;;
                3)
                    if command -v scoop &>/dev/null; then
                        log_info "Using Scoop..."
                    else
                        log_info "Installing Scoop..."
                        powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm get.scoop.sh | iex"
                    fi
                    ;;
                *)
                    log_info "Skipping package manager setup"
                    ;;
            esac
            ;;
    esac
}

# Decrypt GPG-encrypted files
decrypt_sensitive_files() {
    log_info "Checking for encrypted files that need decryption..."

    local encrypted_files=(
        "$HOME/.ftj_config_files.tar.gz.gpg"
        "$HOME/.env.gpg"
        "$HOME/.gnupg.tar.gz.gpg"
        "$HOME/.ssh/id_rsa.gpg"
    )

    for file in "${encrypted_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Found encrypted file: $file"
            read -p "Decrypt $file? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                local output="${file%.gpg}"
                gpg --decrypt --output "$output" "$file" && log_success "Decrypted: $output"

                # Handle tar.gz files
                if [[ "$output" == *.tar.gz ]]; then
                    read -p "Extract $output? (y/n) " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        tar -xzf "$output" -C "$(dirname "$output")"
                        log_success "Extracted: $output"
                    fi
                fi
            fi
        fi
    done
}

# Interactive configuration wizard
run_wizard() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}           ${GREEN}Dotfiles Configuration Wizard${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "Let's configure your dotfiles..."
    echo ""

    # Git configuration
    echo -e "${YELLOW}Git Configuration${NC}"
    read -p "Your name for git commits: " git_name
    read -p "Your email for git commits: " git_email

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    log_success "Git configured with: $git_name <$git_email>"

    # SSH key setup
    echo ""
    echo -e "${YELLOW}SSH Key Setup${NC}"
    if [[ -f "$HOME/.ssh/id_rsa" ]] || [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        log_info "SSH key already exists"
    else
        read -p "Generate new SSH key? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ssh-keygen -t ed25519 -C "$git_email"
            log_success "SSH key generated"
            echo ""
            echo "Add this key to GitHub: https://github.com/settings/keys"
            echo ""
            cat "$HOME/.ssh/id_ed25519.pub"
        fi
    fi

    echo ""
    log_success "Configuration complete!"
}

# Main installation function
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}         ${BLUE}Dotfiles Installation Script${NC}                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         ${YELLOW}Cross-Platform (macOS/Linux/Windows)${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Detect environment
    local os=$(detect_os)
    local shell_type=$(detect_shell)

    log_info "Detected OS: $os"
    log_info "Detected Shell: $shell_type"
    echo ""

    # Installation steps
    echo "This script will:"
    echo "  1. Clone dotfiles as a bare git repository to ~/.dotfiles"
    echo "  2. Checkout dotfiles to your home directory"
    echo "  3. Set up the 'dotfiles' command with shell completion"
    echo "  4. Install platform-specific packages (optional)"
    echo "  5. Run the configuration wizard (optional)"
    echo ""

    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    echo ""

    # Run installation steps
    # clone_dotfiles
    # checkout_dotfiles
    clone_and_checkout_fixed
    setup_dotfiles_alias "$shell_type"
    setup_completion "$shell_type"

    # Optional: Install packages
    echo ""
    read -p "Install platform-specific packages? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_packages "$os"
    fi

    # Setup security hooks (always recommended)
    echo ""
    log_info "Setting up security hooks to prevent committing sensitive data..."
    if [[ -f "$HOME/setup-hooks.sh" ]]; then
        bash "$HOME/setup-hooks.sh"
    fi

    # Optional: Decrypt sensitive files
    echo ""
    read -p "Decrypt sensitive files (GPG encrypted)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        decrypt_sensitive_files
    fi

    # Optional: Run wizard
    echo ""
    read -p "Run configuration wizard? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_wizard
    fi

    # Final instructions
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              ${BLUE}Installation Complete!${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Usage:"
    echo "  dotfiles status              # Check status"
    echo "  dotfiles add <file>          # Stage a file"
    echo "  dotfiles commit -m 'msg'     # Commit changes"
    echo "  dotfiles push                # Push to remote"
    echo ""
    echo "Reload your shell or run:"
    echo "  source ~/${shell_type}rc"
    echo ""

    if [[ -n "$DOTFILES_BACKUP" ]] && [[ -d "$DOTFILES_BACKUP" ]]; then
        log_info "Your original files were backed up to: $DOTFILES_BACKUP"
    fi
}

# Run main function
main "$@"
