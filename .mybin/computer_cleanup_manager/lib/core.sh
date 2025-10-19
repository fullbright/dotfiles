#!/bin/bash
#
# lib/core.sh - Core utility functions with error handling and logging
#

# Color codes for output
readonly RED=$'\e[0;31m'
readonly GREEN=$'\e[0;32m'
readonly YELLOW=$'\e[0;33m'
readonly BLUE=$'\e[0;34m'
readonly MAGENTA=$'\e[0;35m'
readonly CYAN=$'\e[0;36m'
readonly BOLD=$'\e[1m'
readonly NC=$'\e[0m'  # No Color

# Logging levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3
readonly LOG_SUCCESS=4

# Current log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-$LOG_INFO}
VERBOSE=${VERBOSE:-false}

# Logging functions
log_message() {
    local level=$1
    local color=$2
    local prefix=$3
    shift 3
    local message="$*"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    if [[ $level -ge $LOG_LEVEL ]] || [[ "$VERBOSE" == "true" ]]; then
        echo "${color}${prefix}${NC} $message" >&2
    fi
    
    # Always log to file if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$timestamp] $prefix $message" >> "$LOG_FILE"
    fi
}

log_debug() {
    log_message $LOG_DEBUG "$CYAN" "[DEBUG]" "$@"
}

log_info() {
    log_message $LOG_INFO "$BLUE" "[INFO] " "$@"
}

log_warn() {
    log_message $LOG_WARN "$YELLOW" "[WARN] " "$@"
}

log_error() {
    log_message $LOG_ERROR "$RED" "[ERROR]" "$@"
}

log_success() {
    log_message $LOG_SUCCESS "$GREEN" "[OK]   " "$@"
}

log_header() {
    local msg="$*"
    local line=$(printf '=%.0s' $(seq 1 ${#msg}))
    echo ""
    echo "${BOLD}${MAGENTA}$line${NC}"
    echo "${BOLD}${MAGENTA}$msg${NC}"
    echo "${BOLD}${MAGENTA}$line${NC}"
    echo ""
}

log_section() {
    echo ""
    echo "${BOLD}${CYAN}>>> $*${NC}"
    echo ""
}

log_separator() {
    echo "${CYAN}$(printf -- '-%.0s' {1..80})${NC}"
}

# Error handling
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Require command to exist
require_command() {
    local cmd=$1
    local install_msg=${2:-"Please install $cmd"}
    
    if ! command_exists "$cmd"; then
        error_exit "$cmd is required but not installed. $install_msg"
    fi
}

# Verify required tools
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    require_command "git" "Install from https://git-scm.com/"
    require_command "gh" "Install from https://cli.github.com/"
    
    # Check if gh is authenticated
    if ! gh auth status &>/dev/null; then
        error_exit "GitHub CLI is not authenticated. Run: gh auth login"
    fi
    
    # Optional tools
    if ! command_exists "gpg"; then
        log_warn "GPG not found. File encryption will be skipped."
    fi
    
    log_success "Prerequisites check passed"
}

# Load configuration file
load_config() {
    local config_file=$1
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading configuration from: $config_file"
        
        # Source the config file safely
        set -a
        # shellcheck disable=SC1090
        source "$config_file"
        set +a
        
        log_success "Configuration loaded"
    else
        log_info "No configuration file found at: $config_file"
        log_info "Using default configuration"
    fi
}

# Git repository functions
is_git_repo() {
    local folder=$1
    [[ -d "$folder/.git" ]]
}

get_remote_url() {
    local folder=$1
    local url
    # Use 2>&1 to capture stderr and prevent it from appearing in output
    url=$(git -C "$folder" ls-remote --get-url origin 2>&1)
    
    # Check if it's a valid URL (not an error message)
    if [[ $? -eq 0 ]] && [[ "$url" =~ ^https?:// ]] || [[ "$url" =~ ^git@ ]]; then
        echo "$url"
        return 0
    else
        return 1
    fi
}

has_uncommitted_changes() {
    local folder=$1
    local changes
    local untracked
    
    changes=$(git -C "$folder" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git -C "$folder" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $changes -gt 0 ]] || [[ $untracked -gt 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

get_repo_stats() {
    local folder=$1
    local changes untracked remote_url
    
    changes=$(git -C "$folder" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git -C "$folder" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    remote_url=$(get_remote_url "$folder")
    
    echo "changes=$changes|untracked=$untracked|remote=$remote_url"
}

show_repo_status() {
    local folder=$1
    local stats
    stats=$(get_repo_stats "$folder")
    
    local changes untracked remote_url
    IFS='|' read -r changes untracked remote_url <<< "$stats"
    
    changes=${changes#changes=}
    untracked=${untracked#untracked=}
    remote_url=${remote_url#remote=}
    
    log_info "Repository Status:"
    echo "  ${YELLOW}Tracked changes:${NC} $changes"
    echo "  ${YELLOW}Untracked files:${NC} $untracked"
    echo "  ${YELLOW}Remote URL:${NC} $remote_url"
    echo ""
    
    # Show git status
    git -C "$folder" status --short
}

# Check if repository belongs to user
is_my_repository() {
    local remote_url=$1
    local my_accounts=("${MY_GITHUB_ACCOUNTS[@]:-fullbright BrightSoftwares sergioafanou}")
    
    for account in "${my_accounts[@]}"; do
        if [[ "$remote_url" == *"github.com/${account}"* ]]; then
            echo "true"
            return 0
        fi
    done
    
    echo "false"
    return 1
}

# Interactive prompts
prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "${CYAN}${prompt} ${NC}(y/n): " -r response </dev/tty
        case "$response" in
            [Yy]*)
                return 0
                ;;
            [Nn]*)
                return 1
                ;;
            *)
                echo "Please answer yes or no." >&2
                ;;
        esac
    done
}

prompt_continue_or_skip() {
    local prompt="${1:-Continue?}"
    local response
    
    while true; do
        read -p "${CYAN}${prompt}${NC} (c=continue/s=skip/a=abort): " -r response </dev/tty
        case "$response" in
            [Cc]*)
                return 0
                ;;
            [Ss]*)
                return 1
                ;;
            [Aa]*)
                return 2
                ;;
            *)
                echo "Please answer c, s, or a." >&2
                ;;
        esac
    done
}

# File operations
delete_folder_safely() {
    local folder=$1
    
    log_warn "About to delete: $folder"
    
    if ! prompt_yes_no "Are you absolutely sure?"; then
        log_info "Deletion cancelled"
        return 1
    fi
    
    # Create backup before deletion
    local backup_dir="${BACKUP_DIR:-$HOME/.cleanup_backups}"
    mkdir -p "$backup_dir"
    
    local folder_name="$(basename "$folder")"
    local backup_path="$backup_dir/${folder_name}_$(date +'%Y%m%d%H%M%S').tar.gz"
    
    log_info "Creating backup: $backup_path"
    if tar -czf "$backup_path" -C "$(dirname "$folder")" "$folder_name"; then
        log_success "Backup created"
        
        if rm -rf "$folder"; then
            log_success "Folder deleted: $folder"
            return 0
        else
            log_error "Failed to delete folder"
            return 1
        fi
    else
        log_error "Failed to create backup. Deletion aborted."
        return 1
    fi
}

should_skip_folder() {
    local folder=$1
    shift
    local skip_folders=("$@")
    local folder_name="$(basename "$folder")"
    
    for skip in "${skip_folders[@]}"; do
        if [[ "$folder_name" == "$skip" ]] || [[ "$folder" == "$skip" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Sensitive file handling
declare -a SENSITIVE_PATTERNS=(
    ".env"
    ".env.*"
    "*config.json"
    "*config.yaml"
    "*secrets.yml"
    "*keys.json"
    "*credentials*"
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
)

find_sensitive_files() {
    local folder=$1
    local found=()
    
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        while IFS= read -r file; do
            found+=("$file")
        done < <(find "$folder" -maxdepth 2 -name "$pattern" 2>/dev/null)
    done
    
    printf '%s\n' "${found[@]}"
}

handle_sensitive_files() {
    local folder=$1
    local sensitive_files
    
    mapfile -t sensitive_files < <(find_sensitive_files "$folder")
    
    if [[ ${#sensitive_files[@]} -eq 0 ]]; then
        log_info "No sensitive files detected"
        return 0
    fi
    
    log_warn "Found ${#sensitive_files[@]} sensitive file(s):"
    printf '  %s\n' "${sensitive_files[@]}"
    echo ""
    
    if ! prompt_yes_no "Encrypt these files with GPG?"; then
        log_info "Skipping encryption"
        return 0
    fi
    
    if ! command_exists "gpg"; then
        log_error "GPG not available for encryption"
        return 1
    fi
    
    local passphrase="${GPG_PASSPHRASE:-}"
    if [[ -z "$passphrase" ]]; then
        read -s -p "Enter GPG passphrase: " passphrase
        echo ""
    fi
    
    for file in "${sensitive_files[@]}"; do
        log_info "Encrypting: $(basename "$file")"
        
        if echo "$passphrase" | gpg --batch --yes --passphrase-fd 0 \
            --symmetric --cipher-algo AES256 "$file"; then
            
            # Add to .gitignore
            echo "$(basename "$file")" >> "$folder/.gitignore"
            
            log_success "Encrypted: $(basename "$file")"
        else
            log_error "Failed to encrypt: $(basename "$file")"
        fi
    done
}

# .gitignore generation
generate_gitignore() {
    local folder=$1
    local gitignore="$folder/.gitignore"
    
    log_info "Generating/updating .gitignore"
    
    # Common patterns
    local common_patterns=(
        ".DS_Store"
        "*.swp"
        "*.swo"
        "*~"
        ".vscode/"
        ".idea/"
        "*.log"
    )
    
    # Project-specific patterns
    if [[ -f "$folder/package.json" ]]; then
        common_patterns+=("node_modules/" "npm-debug.log*" "yarn-error.log*")
    fi
    
    if [[ -f "$folder/requirements.txt" ]] || [[ -f "$folder/setup.py" ]]; then
        common_patterns+=("__pycache__/" "*.py[cod]" ".venv/" "venv/" "*.egg-info/")
    fi
    
    if [[ -f "$folder/composer.json" ]]; then
        common_patterns+=("vendor/")
    fi
    
    if [[ -f "$folder/Gemfile" ]]; then
        common_patterns+=("vendor/bundle/")
    fi
    
    # Add patterns if not already present
    touch "$gitignore"
    
    for pattern in "${common_patterns[@]}"; do
        if ! grep -qF "$pattern" "$gitignore"; then
            echo "$pattern" >> "$gitignore"
        fi
    done
    
    log_success ".gitignore updated"
}

# Git operations
commit_and_push() {
    local folder=$1
    local branch=$2
    local commit_msg="${3:-Automated migration from Mac cleanup}"
    
    cd "$folder" || return 1
    
    log_info "Creating branch: $branch"
    if ! git checkout -b "$branch" 2>/dev/null; then
        log_warn "Branch already exists, checking out"
        git checkout "$branch"
    fi
    
    log_info "Adding files to git"
    git add .
    
    log_info "Committing changes"
    if ! git commit -m "$commit_msg"; then
        log_error "Commit failed"
        return 1
    fi
    
    log_info "Pushing to origin"
    if ! git push --set-upstream origin "$branch"; then
        log_error "Push failed"
        return 1
    fi
    
    log_success "Successfully pushed to $branch"
    return 0
}

# Explore folder in file manager
explore_folder() {
    local folder=$1
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$folder" 2>/dev/null
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "$folder" 2>/dev/null || nautilus "$folder" 2>/dev/null
    fi
}

# Cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: $exit_code"
    fi
    
    # Save state before exiting
    if command -v state_save_checkpoint &>/dev/null; then
        state_save_checkpoint
    fi
}

trap cleanup_on_exit EXIT

# Export functions for use in other scripts
export -f log_debug log_info log_warn log_error log_success
export -f log_header log_section log_separator
export -f error_exit command_exists require_command
export -f is_git_repo get_remote_url has_uncommitted_changes
export -f is_my_repository prompt_yes_no
export -f delete_folder_safely generate_gitignore
export -f handle_sensitive_files commit_and_push