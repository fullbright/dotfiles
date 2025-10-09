#!/bin/bash
#
# cleanup_manager.sh - Main orchestrator for Mac cleanup and GitHub organization
# Production-ready version with error handling, logging, and state management
#

set -euo pipefail
IFS=$'\n\t'

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/core.sh"
source "${SCRIPT_DIR}/lib/state.sh"
source "${SCRIPT_DIR}/lib/github.sh"

# Initialize logging
LOG_FILE="${SCRIPT_DIR}/logs/cleanup_$(date +'%Y%m%d_%H%M%S').log"
mkdir -p "${SCRIPT_DIR}/logs"

# Configuration
CONFIG_FILE="${SCRIPT_DIR}/.cleanup.config"
load_config "$CONFIG_FILE"

# Global variables
COMPLETED_FOLDER="${COMPLETED_FOLDER:-$HOME/dev_completed}"
BRANCH_PREFIX="migration-$(date +'%Y%m%d-%H%M%S')"
DRY_RUN="${DRY_RUN:-false}"

# Usage function
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <target_directory>

Main orchestrator for Mac cleanup and GitHub repository organization.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run          Run without making changes (preview mode)
    -r, --resume           Resume from last checkpoint
    -s, --skip <folder>    Skip specific folder
    -o, --owner <name>     Set default GitHub owner/org
    -v, --verbose          Enable verbose logging
    --analyze-only         Only analyze and categorize folders
    --batch-size <n>       Process n folders at a time (default: 1)

EXAMPLES:
    $(basename "$0") ~/dev
    $(basename "$0") --dry-run ~/dev
    $(basename "$0") --resume ~/dev
    $(basename "$0") --owner BrightSoftwares ~/dev

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    ANALYZE_ONLY=false
    RESUME=false
    BATCH_SIZE=1
    SKIP_FOLDERS=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_info "DRY RUN MODE ENABLED - No changes will be made"
                shift
                ;;
            -r|--resume)
                RESUME=true
                shift
                ;;
            -s|--skip)
                SKIP_FOLDERS+=("$2")
                shift 2
                ;;
            -o|--owner)
                DEFAULT_OWNER="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --analyze-only)
                ANALYZE_ONLY=true
                shift
                ;;
            --batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "${TARGET_DIR:-}" ]]; then
        log_error "Target directory is required"
        usage
    fi
    
    if [[ ! -d "$TARGET_DIR" ]]; then
        log_error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi
}

# Analyze a folder and determine its category
analyze_folder() {
    local folder="$1"
    local folder_name="$(basename "$folder")"
    
    log_debug "Analyzing folder: $folder"
    
    # Check if should skip
    if should_skip_folder "$folder" "${SKIP_FOLDERS[@]:-}"; then
        log_info "Skipping folder (user requested): $folder_name"
        return 1
    fi
    
    # Check if already processed
    if state_is_processed "$folder"; then
        log_info "Skipping folder (already processed): $folder_name"
        return 1
    fi
    
    # Determine folder category
    if ! is_git_repo "$folder"; then
        categorize_folder "$folder" "not_a_repo"
        return 0
    fi
    
    local remote_url
    remote_url=$(get_remote_url "$folder") || {
        categorize_folder "$folder" "no_remote"
        return 0
    }
    
    local is_my_repo
    is_my_repo=$(is_my_repository "$remote_url")
    
    if [[ "$is_my_repo" == "false" ]]; then
        categorize_folder "$folder" "external_to_fork"
        return 0
    fi
    
    local has_changes
    has_changes=$(has_uncommitted_changes "$folder")
    
    if [[ "$has_changes" == "true" ]]; then
        categorize_folder "$folder" "my_repo_with_changes"
    else
        categorize_folder "$folder" "my_repo_clean"
    fi
    
    return 0
}

# Process folders based on their category
process_folder_by_category() {
    local folder="$1"
    local category="$2"
    
    log_section "Processing: $(basename "$folder") [$category]"
    
    case "$category" in
        not_a_repo)
            process_non_repo "$folder"
            ;;
        no_remote)
            process_no_remote "$folder"
            ;;
        external_to_fork)
            process_external_repo "$folder"
            ;;
        my_repo_with_changes)
            process_repo_with_changes "$folder"
            ;;
        my_repo_clean)
            process_clean_repo "$folder"
            ;;
        *)
            log_error "Unknown category: $category"
            return 1
            ;;
    esac
}

# Process a non-repository folder
process_non_repo() {
    local folder="$1"
    
    log_info "Folder is not a Git repository"
    
    # Open in Finder for user review
    if command -v open &>/dev/null; then
        open "$folder"
    fi
    
    if prompt_yes_no "Do you want to keep this folder and create a repository?"; then
        local owner
        owner=$(select_github_owner)
        
        if create_and_link_repo "$folder" "$owner"; then
            process_repo_with_changes "$folder"
        else
            log_error "Failed to create repository"
            return 1
        fi
    else
        log_info "Folder will be left as-is"
        state_mark_skipped "$folder"
    fi
}

# Process a repository without a remote
process_no_remote() {
    local folder="$1"
    
    log_info "Repository has no remote configured"
    
    if prompt_yes_no "Create a GitHub repository for this?"; then
        local owner
        owner=$(select_github_owner)
        
        if link_to_new_repo "$folder" "$owner"; then
            process_repo_with_changes "$folder"
        else
            log_error "Failed to link repository"
            return 1
        fi
    else
        state_mark_skipped "$folder"
    fi
}

# Process an external repository to fork
process_external_repo() {
    local folder="$1"
    local remote_url
    remote_url=$(get_remote_url "$folder")
    
    log_info "External repository: $remote_url"
    
    if prompt_yes_no "Fork this repository to your account?"; then
        local owner
        owner=$(select_github_owner)
        
        if fork_and_update_remote "$folder" "$owner"; then
            process_repo_with_changes "$folder"
        else
            log_error "Failed to fork repository"
            return 1
        fi
    else
        state_mark_skipped "$folder"
    fi
}

# Process a repository with uncommitted changes
process_repo_with_changes() {
    local folder="$1"
    
    show_repo_status "$folder"
    
    if ! prompt_yes_no "Commit and push changes to a new branch?"; then
        state_mark_skipped "$folder"
        return 0
    fi
    
    # Generate .gitignore
    generate_gitignore "$folder"
    
    # Handle sensitive files
    handle_sensitive_files "$folder"
    
    # Create branch and commit
    local branch_name="${BRANCH_PREFIX}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create branch: $branch_name"
        log_info "[DRY RUN] Would commit and push changes"
    else
        if commit_and_push "$folder" "$branch_name"; then
            log_success "Changes pushed to branch: $branch_name"
            move_to_completed "$folder"
            state_mark_completed "$folder"
        else
            log_error "Failed to commit and push changes"
            return 1
        fi
    fi
}

# Process a clean repository
process_clean_repo() {
    local folder="$1"
    
    show_repo_status "$folder"
    
    log_info "Repository is clean (no uncommitted changes)"
    
    if prompt_yes_no "Delete this clean repository?"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would delete: $folder"
        else
            if delete_folder_safely "$folder"; then
                state_mark_deleted "$folder"
            else
                log_error "Failed to delete folder"
                return 1
            fi
        fi
    else
        move_to_completed "$folder"
        state_mark_completed "$folder"
    fi
}

# Move folder to completed directory
move_to_completed() {
    local folder="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would move to: $COMPLETED_FOLDER"
        return 0
    fi
    
    mkdir -p "$COMPLETED_FOLDER"
    
    local folder_name="$(basename "$folder")"
    local dest="$COMPLETED_FOLDER/$folder_name"
    
    if [[ -d "$dest" ]]; then
        dest="${dest}_$(date +'%Y%m%d%H%M%S')"
    fi
    
    if mv "$folder" "$dest"; then
        log_success "Moved to: $dest"
        return 0
    else
        log_error "Failed to move folder"
        return 1
    fi
}

# Main execution
main() {
    log_header "Mac Cleanup and GitHub Organization Tool"
    
    parse_args "$@"
    
    # Initialize state management
    state_init "$TARGET_DIR"
    
    # Load or resume state
    if [[ "$RESUME" == "true" ]] && state_can_resume; then
        log_info "Resuming from previous session"
        state_load
    else
        log_info "Starting new cleanup session"
        state_reset
    fi
    
    # Get list of folders to process
    local folders=()
    while IFS= read -r -d '' folder; do
        folders+=("$folder")
    done < <(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    
    local total=${#folders[@]}
    log_info "Found $total folders to process"
    
    if [[ "$ANALYZE_ONLY" == "true" ]]; then
        log_info "ANALYZE-ONLY MODE: No changes will be made"
    fi
    
    # Process each folder
    local processed=0
    local skipped=0
    local failed=0
    
    for folder in "${folders[@]}"; do
        local folder_name="$(basename "$folder")"
        
        log_separator
        log_info "[$((processed + skipped + failed + 1))/$total] $folder_name"
        
        # Analyze folder
        if ! analyze_folder "$folder"; then
            ((skipped++))
            continue
        fi
        
        # Get category
        local category
        category=$(get_folder_category "$folder")
        
        if [[ "$ANALYZE_ONLY" == "true" ]]; then
            log_info "Category: $category"
            ((processed++))
            continue
        fi
        
        # Process folder
        if process_folder_by_category "$folder" "$category"; then
            ((processed++))
            state_save_checkpoint
        else
            ((failed++))
            log_error "Failed to process: $folder_name"
            
            if ! prompt_yes_no "Continue with next folder?"; then
                log_info "User aborted process"
                break
            fi
        fi
    done
    
    # Summary
    log_separator
    log_header "Cleanup Summary"
    log_info "Total folders: $total"
    log_success "Processed: $processed"
    log_info "Skipped: $skipped"
    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed"
    fi
    
    # Generate reports
    generate_summary_report
    
    log_success "Cleanup process completed!"
}

# Run main function
main "$@"