#!/bin/bash
#
# lib/github.sh - GitHub repository operations
#

# GitHub owner/org management
declare -a GITHUB_OWNERS=()
SELECTED_OWNER=""

# Initialize GitHub owners list
init_github_owners() {
    # Load from config or use defaults
    if [[ -n "${DEFAULT_GITHUB_OWNERS:-}" ]]; then
        IFS=',' read -ra GITHUB_OWNERS <<< "$DEFAULT_GITHUB_OWNERS"
    else
        GITHUB_OWNERS=("fullbright" "BrightSoftwares")
    fi
    
    # Add current authenticated user if not already in list
    local current_user
    current_user=$(gh api user --jq .login 2>/dev/null)
    if [[ -n "$current_user" ]] && [[ ! " ${GITHUB_OWNERS[*]} " =~ " ${current_user} " ]]; then
        GITHUB_OWNERS+=("$current_user")
    fi
    
    # Remove duplicates while preserving order
    local -a unique_owners=()
    local -A seen=()
    for owner in "${GITHUB_OWNERS[@]}"; do
        if [[ -z "${seen[$owner]:-}" ]]; then
            unique_owners+=("$owner")
            seen[$owner]=1
        fi
    done
    GITHUB_OWNERS=("${unique_owners[@]}")
    
    log_debug "GitHub owners initialized: ${GITHUB_OWNERS[*]}"
}

# Initialize on source
init_github_owners

# Select GitHub owner interactively
select_github_owner() {
    # If DEFAULT_OWNER is set, use it
    if [[ -n "${DEFAULT_OWNER:-}" ]]; then
        echo "$DEFAULT_OWNER"
        return 0
    fi
    
    # If only one owner, use it
    if [[ ${#GITHUB_OWNERS[@]} -eq 1 ]]; then
        echo "${GITHUB_OWNERS[0]}"
        return 0
    fi
    
    # Send prompts to stderr to avoid capturing them
    echo "" >&2
    echo "${CYAN}Select GitHub owner/organization:${NC}" >&2
    
    local i=1
    for owner in "${GITHUB_OWNERS[@]}"; do
        echo "  $i) $owner" >&2
        ((i++))
    done
    echo "  $i) Enter new owner/org" >&2
    echo "" >&2
    
    local selected_owner=""
    
    while true; do
        read -p "Selection [1-$i]: " -r selection </dev/tty
        
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            if (( selection > 0 && selection < i )); then
                selected_owner="${GITHUB_OWNERS[$((selection - 1))]}"
                
                # Remember this selection as default for this session
                DEFAULT_OWNER="$selected_owner"
                
                # Only echo the result to stdout
                echo "$selected_owner"
                return 0
            elif (( selection == i )); then
                read -p "Enter owner/org name: " -r new_owner </dev/tty
                
                if [[ -n "$new_owner" ]]; then
                    # Verify owner exists
                    if verify_github_owner "$new_owner"; then
                        GITHUB_OWNERS+=("$new_owner")
                        DEFAULT_OWNER="$new_owner"
                        echo "$new_owner"
                        return 0
                    else
                        log_error "Could not verify GitHub owner: $new_owner"
                        continue
                    fi
                fi
            fi
        fi
        
        echo "Invalid selection. Please try again." >&2
    done
}

# Verify GitHub owner exists
verify_github_owner() {
    local owner=$1
    
    log_debug "Verifying GitHub owner: $owner"
    
    # Try as user first
    if gh api "users/$owner" &>/dev/null; then
        log_debug "Verified as user: $owner"
        return 0
    fi
    
    # Try as organization
    if gh api "orgs/$owner" &>/dev/null; then
        log_debug "Verified as organization: $owner"
        return 0
    fi
    
    return 1
}

# Check if repository exists
repo_exists() {
    local owner=$1
    local repo_name=$2
    
    gh repo view "$owner/$repo_name" &>/dev/null
}

# Create GitHub repository
create_github_repo() {
    local owner=$1
    local repo_name=$2
    local visibility="${3:-public}"
    
    log_info "Creating GitHub repository: $owner/$repo_name"
    
    local create_args=(
        "$owner/$repo_name"
        "--$visibility"
        "--description" "Migrated from Mac cleanup process"
    )
    
    if gh repo create "${create_args[@]}"; then
        log_success "Repository created: $owner/$repo_name"
        return 0
    else
        log_error "Failed to create repository"
        return 1
    fi
}

# Fork repository
fork_repository() {
    local source_url=$1
    local target_owner=$2
    local repo_name=$3
    
    log_info "Forking repository: $source_url"
    log_info "Target: $target_owner/$repo_name"
    
    local fork_args=(
        "$source_url"
        "--clone=false"
        "--fork-name" "$repo_name"
    )
    
    # Check if target is organization
    if gh api "orgs/$target_owner" &>/dev/null; then
        fork_args+=("--org" "$target_owner")
    fi
    
    if gh repo fork "${fork_args[@]}"; then
        log_success "Repository forked successfully"
        return 0
    else
        log_error "Failed to fork repository"
        return 1
    fi
}

# Create and link repository to local folder
create_and_link_repo() {
    local folder=$1
    local owner=$2
    local repo_name
    repo_name=$(basename "$folder")
    
    # Check if repo already exists
    if repo_exists "$owner" "$repo_name"; then
        log_warn "Repository $owner/$repo_name already exists"
        
        if prompt_yes_no "Clone existing repository and merge?"; then
            return link_to_existing_repo "$folder" "$owner" "$repo_name"
        else
            log_info "User chose not to link to existing repository"
            return 1
        fi
    fi
    
    # Initialize git if not already
    if ! is_git_repo "$folder"; then
        log_info "Initializing git repository"
        git -C "$folder" init || return 1
    fi
    
    # Create GitHub repository
    if ! create_github_repo "$owner" "$repo_name"; then
        return 1
    fi
    
    # Add remote
    local remote_url="https://github.com/$owner/$repo_name.git"
    
    log_info "Adding remote: $remote_url"
    git -C "$folder" remote add origin "$remote_url" 2>/dev/null || \
        git -C "$folder" remote set-url origin "$remote_url"
    
    log_success "Repository created and linked"
    return 0
}

# Link folder to new repository
link_to_new_repo() {
    local folder=$1
    local owner=$2
    
    create_and_link_repo "$folder" "$owner"
}

# Link to existing repository
link_to_existing_repo() {
    local folder=$1
    local owner=$2
    local repo_name=$3
    
    local remote_url="https://github.com/$owner/$repo_name.git"
    
    log_info "Linking to existing repository: $remote_url"
    
    # Check if we need to handle existing content
    if [[ -n "$(ls -A "$folder")" ]]; then
        log_warn "Folder contains existing files"
        
        if prompt_yes_no "Create temporary backup and clone fresh?"; then
            local backup_dir="${folder}_backup_$(date +'%Y%m%d%H%M%S')"
            
            log_info "Creating backup: $backup_dir"
            mv "$folder" "$backup_dir"
            
            log_info "Cloning repository"
            if gh repo clone "$owner/$repo_name" "$folder"; then
                log_info "Copying files from backup"
                cp -r "$backup_dir/"* "$folder/" 2>/dev/null || true
                cp -r "$backup_dir/".* "$folder/" 2>/dev/null || true
                
                log_success "Repository cloned and files restored"
                log_info "Backup kept at: $backup_dir"
                return 0
            else
                log_error "Failed to clone repository"
                mv "$backup_dir" "$folder"
                return 1
            fi
        fi
    fi
    
    # Just add/update remote
    if is_git_repo "$folder"; then
        git -C "$folder" remote add origin "$remote_url" 2>/dev/null || \
            git -C "$folder" remote set-url origin "$remote_url"
    else
        git -C "$folder" init
        git -C "$folder" remote add origin "$remote_url"
    fi
    
    log_success "Remote configured"
    return 0
}

# Fork and update remote
fork_and_update_remote() {
    local folder=$1
    local target_owner=$2
    
    local source_url
    source_url=$(get_remote_url "$folder") || {
        log_error "Could not get remote URL"
        return 1
    }
    
    local repo_name
    repo_name=$(basename "$folder")
    
    # Check if fork already exists
    if repo_exists "$target_owner" "$repo_name"; then
        log_warn "Fork already exists: $target_owner/$repo_name"
    else
        # Fork the repository
        if ! fork_repository "$source_url" "$target_owner" "$repo_name"; then
            return 1
        fi
        
        # Wait a moment for GitHub to process the fork
        sleep 2
    fi
    
    # Update remote URL
    local fork_url="https://github.com/$target_owner/$repo_name.git"
    
    log_info "Updating remote to fork: $fork_url"
    git -C "$folder" remote set-url origin "$fork_url"
    
    # Add upstream remote if not exists
    if ! git -C "$folder" remote | grep -q "^upstream$"; then
        log_info "Adding upstream remote: $source_url"
        git -C "$folder" remote add upstream "$source_url"
    fi
    
    log_success "Repository forked and remotes configured"
    return 0
}

# Search for similar repositories
search_similar_repos() {
    local owner=$1
    local query=$2
    
    log_info "Searching for repositories matching: $query"
    
    local results
    results=$(gh repo list "$owner" --limit 100 --json name,url,description | \
        jq -r --arg q "$query" '.[] | select(.name | contains($q)) | "\(.name)|\(.url)"')
    
    if [[ -n "$results" ]]; then
        echo "$results"
        return 0
    else
        return 1
    fi
}

# Get repository information
get_repo_info() {
    local owner=$1
    local repo_name=$2
    
    gh api "repos/$owner/$repo_name" 2>/dev/null | jq -r '{
        name: .name,
        description: .description,
        private: .private,
        fork: .fork,
        archived: .archived,
        created_at: .created_at,
        updated_at: .updated_at,
        size: .size
    }'
}

# Check repository permissions
check_repo_permissions() {
    local owner=$1
    local repo_name=$2
    
    local permissions
    permissions=$(gh api "repos/$owner/$repo_name" --jq .permissions 2>/dev/null)
    
    if [[ -n "$permissions" ]]; then
        echo "$permissions" | jq -r 'to_entries | .[] | "\(.key): \(.value)"'
        return 0
    else
        return 1
    fi
}

# Export functions
export -f init_github_owners select_github_owner verify_github_owner
export -f repo_exists create_github_repo fork_repository
export -f create_and_link_repo link_to_new_repo link_to_existing_repo
export -f fork_and_update_remote search_similar_repos
export -f get_repo_info check_repo_permissions