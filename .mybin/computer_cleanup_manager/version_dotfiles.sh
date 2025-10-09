#!/bin/bash
#
# version_dotfiles.sh - Version home directory folders in dotfiles repository
# Manages symlinks and tracks important configuration directories
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/core.sh"

# Configuration
DOTFILES_REPO="${DOTFILES_REPO:-$HOME/dotfiles}"
DOTFILES_REMOTE="${DOTFILES_REMOTE:-https://github.com/fullbright/dotfiles.git}"
BACKUP_DIR="$HOME/.dotfiles_backup"

# Directories to version (can be configured)
declare -a DEFAULT_DIRS=(
    ".config"
    ".ssh"
    ".gnupg"
    ".aws"
    ".kube"
    "scripts"
)

# Files to version
declare -a DEFAULT_FILES=(
    ".bashrc"
    ".bash_profile"
    ".zshrc"
    ".zsh_profile"
    ".vimrc"
    ".gitconfig"
    ".gitignore_global"
    ".tmux.conf"
)

# Patterns to exclude
declare -a EXCLUDE_PATTERNS=(
    "*.log"
    "*.cache"
    "*_history"
    "Cache/"
    "cache/"
    "node_modules/"
    "__pycache__/"
)

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Version home directory folders and files in dotfiles repository.

OPTIONS:
    -h, --help              Show this help message
    -i, --init              Initialize dotfiles repository
    -a, --add <path>        Add specific file/folder to dotfiles
    -r, --restore           Restore dotfiles from repository
    -s, --sync              Sync current state to repository
    -l, --list              List currently tracked items
    -u, --untrack <path>    Stop tracking a file/folder
    --dry-run               Show what would be done without making changes

EXAMPLES:
    $(basename "$0") --init                    # Initialize dotfiles repo
    $(basename "$0") --add ~/.config/nvim      # Add nvim config
    $(basename "$0") --sync                    # Sync all changes
    $(basename "$0") --restore                 # Restore from repo

EOF
    exit 1
}

# Initialize dotfiles repository
init_dotfiles() {
    log_header "Initializing Dotfiles Repository"
    
    if [[ -d "$DOTFILES_REPO" ]]; then
        log_warn "Dotfiles repository already exists at: $DOTFILES_REPO"
        
        if ! prompt_yes_no "Reinitialize?"; then
            log_info "Initialization cancelled"
            return 0
        fi
    fi
    
    # Clone or create repository
    if prompt_yes_no "Clone existing dotfiles repository?"; then
        log_info "Enter repository URL (default: $DOTFILES_REMOTE):"
        read -r repo_url
        repo_url=${repo_url:-$DOTFILES_REMOTE}
        
        if [[ -d "$DOTFILES_REPO" ]]; then
            rm -rf "$DOTFILES_REPO"
        fi
        
        if gh repo clone "$repo_url" "$DOTFILES_REPO"; then
            log_success "Dotfiles repository cloned"
        else
            log_error "Failed to clone repository"
            return 1
        fi
    else
        # Create new repository
        mkdir -p "$DOTFILES_REPO"
        cd "$DOTFILES_REPO"
        
        git init
        
        # Create directory structure
        mkdir -p home config scripts
        
        # Create README
        cat > README.md << 'READMEEOF'
# Dotfiles

My personal configuration files and scripts.

## Structure

- `home/` - Files that go in $HOME
- `config/` - Configuration directories (like .config subdirs)
- `scripts/` - Utility scripts

## Installation

```bash
./install.sh
```

## Managed by

This repository is managed by the Mac cleanup automation scripts.
READMEEOF
        
        # Create install script
        cat > install.sh << 'INSTALLEOF'
#!/bin/bash
# Dotfiles installation script

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $DOTFILES_DIR"

# Link files from home/
for file in "$DOTFILES_DIR"/home/.*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        target="$HOME/$filename"
        
        if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            echo "Backing up: $target"
            mv "$target" "${target}.backup"
        fi
        
        echo "Linking: $filename"
        ln -sf "$file" "$target"
    fi
done

# Link directories from config/
for dir in "$DOTFILES_DIR"/config/*; do
    if [[ -d "$dir" ]]; then
        dirname=$(basename "$dir")
        target="$HOME/.config/$dirname"
        
        mkdir -p "$HOME/.config"
        
        if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            echo "Backing up: $target"
            mv "$target" "${target}.backup"
        fi
        
        echo "Linking: .config/$dirname"
        ln -sf "$dir" "$target"
    fi
done

echo "Dotfiles installed!"
INSTALLEOF
        
        chmod +x install.sh
        
        # Initial commit
        git add .
        git commit -m "Initial dotfiles structure"
        
        log_success "Dotfiles repository initialized"
        
        # Optionally create GitHub repo
        if prompt_yes_no "Create GitHub repository?"; then
            local owner
            owner=$(select_github_owner)
            
            if gh repo create "$owner/dotfiles" --public --source=. --remote=origin; then
                log_success "GitHub repository created"
                git push -u origin main || git push -u origin master
            fi
        fi
    fi
    
    log_success "Dotfiles initialization complete"
}

# Add file or folder to dotfiles
add_to_dotfiles() {
    local source_path=$1
    
    # Resolve to absolute path
    if [[ ! "$source_path" =~ ^/ ]]; then
        source_path="$HOME/$source_path"
    fi
    
    # Remove $HOME prefix for relative path
    local rel_path="${source_path#$HOME/}"
    
    if [[ ! -e "$source_path" ]]; then
        log_error "Path does not exist: $source_path"
        return 1
    fi
    
    log_info "Adding to dotfiles: $rel_path"
    
    # Determine destination in dotfiles repo
    local dest_path
    if [[ "$rel_path" == .config/* ]]; then
        # .config subdirectories go in config/
        local config_subdir="${rel_path#.config/}"
        dest_path="$DOTFILES_REPO/config/$config_subdir"
    elif [[ "$rel_path" == .* ]]; then
        # Dotfiles go in home/
        dest_path="$DOTFILES_REPO/home/$rel_path"
    else
        # Everything else goes in scripts or root
        dest_path="$DOTFILES_REPO/$rel_path"
    fi
    
    # Create backup if file/folder exists at destination
    if [[ -e "$dest_path" ]]; then
        log_warn "Destination already exists: $dest_path"
        if ! prompt_yes_no "Overwrite?"; then
            return 1
        fi
        rm -rf "$dest_path"
    fi
    
    # Create parent directory
    mkdir -p "$(dirname "$dest_path")"
    
    # Copy to dotfiles repo
    if [[ -d "$source_path" ]]; then
        log_info "Copying directory: $source_path"
        
        # Use rsync if available for better copying
        if command_exists rsync; then
            rsync -av --exclude-from=<(printf '%s\n' "${EXCLUDE_PATTERNS[@]}") \
                "$source_path/" "$dest_path/"
        else
            cp -r "$source_path" "$dest_path"
        fi
    else
        log_info "Copying file: $source_path"
        cp "$source_path" "$dest_path"
    fi
    
    # Create backup of original
    local backup_path="$BACKUP_DIR/$rel_path"
    mkdir -p "$(dirname "$backup_path")"
    
    if [[ -d "$source_path" ]]; then
        cp -r "$source_path" "$backup_path"
    else
        cp "$source_path" "$backup_path"
    fi
    
    log_info "Backup created: $backup_path"
    
    # Replace original with symlink
    rm -rf "$source_path"
    ln -s "$dest_path" "$source_path"
    
    log_success "Symlink created: $source_path -> $dest_path"
    
    # Commit to git
    cd "$DOTFILES_REPO"
    git add .
    git commit -m "Add $rel_path to dotfiles"
    
    log_success "Added to dotfiles repository"
    
    if prompt_yes_no "Push to remote?"; then
        git push
        log_success "Changes pushed to remote"
    fi
}

# Sync all tracked files
sync_dotfiles() {
    log_header "Syncing Dotfiles"
    
    if [[ ! -d "$DOTFILES_REPO" ]]; then
        log_error "Dotfiles repository not found. Run --init first."
        return 1
    fi
    
    cd "$DOTFILES_REPO"
    
    # Check for changes
    if [[ -z "$(git status --porcelain)" ]]; then
        log_info "No changes to sync"
        return 0
    fi
    
    log_info "Changes detected:"
    git status --short
    echo ""
    
    if ! prompt_yes_no "Commit and push these changes?"; then
        log_info "Sync cancelled"
        return 0
    fi
    
    # Commit changes
    git add .
    
    log_info "Enter commit message (or press Enter for default):"
    read -r commit_msg
    commit_msg=${commit_msg:-"Update dotfiles on $(date +'%Y-%m-%d %H:%M:%S')"}
    
    git commit -m "$commit_msg"
    
    # Push to remote
    if git remote | grep -q origin; then
        git push
        log_success "Changes pushed to remote"
    else
        log_warn "No remote configured. Changes committed locally only."
    fi
    
    log_success "Dotfiles synced"
}

# List tracked items
list_tracked() {
    log_header "Tracked Dotfiles"
    
    if [[ ! -d "$DOTFILES_REPO" ]]; then
        log_error "Dotfiles repository not found"
        return 1
    fi
    
    echo ""
    echo "${BOLD}Files in home/${NC}"
    if [[ -d "$DOTFILES_REPO/home" ]]; then
        find "$DOTFILES_REPO/home" -type f | while read -r file; do
            local rel_path="${file#$DOTFILES_REPO/home/}"
            local home_path="$HOME/$rel_path"
            
            if [[ -L "$home_path" ]]; then
                echo "  ${GREEN}✓${NC} $rel_path (linked)"
            else
                echo "  ${YELLOW}!${NC} $rel_path (not linked)"
            fi
        done
    fi
    
    echo ""
    echo "${BOLD}Directories in config/${NC}"
    if [[ -d "$DOTFILES_REPO/config" ]]; then
        find "$DOTFILES_REPO/config" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
            local dirname=$(basename "$dir")
            local config_path="$HOME/.config/$dirname"
            
            if [[ -L "$config_path" ]]; then
                echo "  ${GREEN}✓${NC} .config/$dirname (linked)"
            else
                echo "  ${YELLOW}!${NC} .config/$dirname (not linked)"
            fi
        done
    fi
    
    echo ""
    echo "${BOLD}Scripts${NC}"
    if [[ -d "$DOTFILES_REPO/scripts" ]]; then
        find "$DOTFILES_REPO/scripts" -type f | while read -r file; do
            local filename=$(basename "$file")
            echo "  ${BLUE}•${NC} $filename"
        done
    fi
    
    echo ""
}

# Restore dotfiles from repository
restore_dotfiles() {
    log_header "Restoring Dotfiles"
    
    if [[ ! -d "$DOTFILES_REPO" ]]; then
        log_error "Dotfiles repository not found"
        return 1
    fi
    
    log_warn "This will replace existing files with repository versions"
    
    if ! prompt_yes_no "Continue with restore?"; then
        log_info "Restore cancelled"
        return 0
    fi
    
    # Run install script if it exists
    if [[ -f "$DOTFILES_REPO/install.sh" ]]; then
        log_info "Running install script"
        bash "$DOTFILES_REPO/install.sh"
    else
        # Manual restore
        log_info "Restoring files manually"
        
        # Restore home files
        if [[ -d "$DOTFILES_REPO/home" ]]; then
            find "$DOTFILES_REPO/home" -type f | while read -r file; do
                local rel_path="${file#$DOTFILES_REPO/home/}"
                local target="$HOME/$rel_path"
                
                if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
                    log_info "Backing up: $rel_path"
                    mv "$target" "${target}.backup"
                fi
                
                log_info "Linking: $rel_path"
                ln -sf "$file" "$target"
            done
        fi
        
        # Restore config directories
        if [[ -d "$DOTFILES_REPO/config" ]]; then
            mkdir -p "$HOME/.config"
            
            find "$DOTFILES_REPO/config" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
                local dirname=$(basename "$dir")
                local target="$HOME/.config/$dirname"
                
                if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
                    log_info "Backing up: .config/$dirname"
                    mv "$target" "${target}.backup"
                fi
                
                log_info "Linking: .config/$dirname"
                ln -sf "$dir" "$target"
            done
        fi
    fi
    
    log_success "Dotfiles restored"
}

# Untrack a file or folder
untrack_item() {
    local item=$1
    
    # Resolve to absolute path
    if [[ ! "$item" =~ ^/ ]]; then
        item="$HOME/$item"
    fi
    
    local rel_path="${item#$HOME/}"
    
    if [[ ! -L "$item" ]]; then
        log_error "Item is not a symlink: $item"
        return 1
    fi
    
    log_info "Untracking: $rel_path"
    
    # Find the target
    local target
    target=$(readlink "$item")
    
    # Copy content back to original location
    local backup_path="$BACKUP_DIR/$rel_path"
    
    if [[ -e "$backup_path" ]]; then
        log_info "Restoring from backup: $backup_path"
        rm "$item"
        cp -r "$backup_path" "$item"
    else
        log_info "Copying from dotfiles repo"
        rm "$item"
        cp -r "$target" "$item"
    fi
    
    # Remove from dotfiles repo
    if prompt_yes_no "Remove from dotfiles repository?"; then
        rm -rf "$target"
        
        cd "$DOTFILES_REPO"
        git add -A
        git commit -m "Untrack $rel_path"
        
        if prompt_yes_no "Push to remote?"; then
            git push
        fi
    fi
    
    log_success "Item untracked: $rel_path"
}

# Add default items
add_default_items() {
    log_header "Adding Default Dotfiles"
    
    local added=0
    
    # Add default files
    for file in "${DEFAULT_FILES[@]}"; do
        local path="$HOME/$file"
        
        if [[ -f "$path" ]] && [[ ! -L "$path" ]]; then
            log_info "Found: $file"
            
            if prompt_yes_no "Add $file to dotfiles?"; then
                if add_to_dotfiles "$path"; then
                    ((added++))
                fi
            fi
        fi
    done
    
    # Add default directories
    for dir in "${DEFAULT_DIRS[@]}"; do
        local path="$HOME/$dir"
        
        if [[ -d "$path" ]] && [[ ! -L "$path" ]]; then
            log_info "Found: $dir/"
            
            if prompt_yes_no "Add $dir/ to dotfiles?"; then
                if add_to_dotfiles "$path"; then
                    ((added++))
                fi
            fi
        fi
    done
    
    log_success "Added $added items to dotfiles"
}

# Main execution
main() {
    local action=""
    local target_path=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -i|--init)
                action="init"
                shift
                ;;
            -a|--add)
                action="add"
                target_path="$2"
                shift 2
                ;;
            -r|--restore)
                action="restore"
                shift
                ;;
            -s|--sync)
                action="sync"
                shift
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -u|--untrack)
                action="untrack"
                target_path="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --add-defaults)
                action="add_defaults"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check prerequisites
    require_command "git"
    
    if [[ "$action" == "init" ]]; then
        require_command "gh"
    fi
    
    # Execute action
    case "$action" in
        init)
            init_dotfiles
            ;;
        add)
            if [[ -z "$target_path" ]]; then
                log_error "No path specified"
                usage
            fi
            add_to_dotfiles "$target_path"
            ;;
        restore)
            restore_dotfiles
            ;;
        sync)
            sync_dotfiles
            ;;
        list)
            list_tracked
            ;;
        untrack)
            if [[ -z "$target_path" ]]; then
                log_error "No path specified"
                usage
            fi
            untrack_item "$target_path"
            ;;
        add_defaults)
            add_default_items
            ;;
        *)
            log_error "No action specified"
            usage
            ;;
    esac
}

main "$@"