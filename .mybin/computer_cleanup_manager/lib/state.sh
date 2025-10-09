#!/bin/bash
#
# lib/state.sh - State management for resumable operations
#

# State directory and files
STATE_DIR="${STATE_DIR:-$HOME/.cleanup_state}"
STATE_FILE="$STATE_DIR/state.json"
CHECKPOINT_FILE="$STATE_DIR/checkpoint.txt"
CATEGORIES_FILE="$STATE_DIR/categories.txt"

# State variables
declare -A FOLDER_STATES
declare -A FOLDER_CATEGORIES

# Initialize state management
state_init() {
    local target_dir="$1"
    
    mkdir -p "$STATE_DIR"
    
    # Create state identifier based on target directory
    local state_id
    state_id=$(echo "$target_dir" | md5sum | cut -d' ' -f1)
    
    STATE_FILE="$STATE_DIR/state_${state_id}.json"
    CHECKPOINT_FILE="$STATE_DIR/checkpoint_${state_id}.txt"
    CATEGORIES_FILE="$STATE_DIR/categories_${state_id}.txt"
    
    log_debug "State initialized for: $target_dir"
    log_debug "State file: $STATE_FILE"
}

# Reset state
state_reset() {
    log_debug "Resetting state"
    
    echo "{}" > "$STATE_FILE"
    echo "" > "$CHECKPOINT_FILE"
    echo "" > "$CATEGORIES_FILE"
    
    FOLDER_STATES=()
    FOLDER_CATEGORIES=()
}

# Check if we can resume
state_can_resume() {
    [[ -f "$STATE_FILE" ]] && [[ -f "$CHECKPOINT_FILE" ]]
}

# Load state from disk
state_load() {
    if [[ ! -f "$STATE_FILE" ]]; then
        log_warn "No state file found"
        return 1
    fi
    
    log_debug "Loading state from: $STATE_FILE"
    
    # Load processed folders
    while IFS='=' read -r folder status; do
        if [[ -n "$folder" ]] && [[ -n "$status" ]]; then
            FOLDER_STATES["$folder"]="$status"
        fi
    done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value.status)"' "$STATE_FILE" 2>/dev/null)
    
    # Load categories
    if [[ -f "$CATEGORIES_FILE" ]]; then
        while IFS='|' read -r folder category; do
            if [[ -n "$folder" ]] && [[ -n "$category" ]]; then
                FOLDER_CATEGORIES["$folder"]="$category"
            fi
        done < "$CATEGORIES_FILE"
    fi
    
    log_success "State loaded: ${#FOLDER_STATES[@]} folders tracked"
}

# Save checkpoint
state_save_checkpoint() {
    log_debug "Saving checkpoint"
    
    # Save folder states to JSON
    local json_content="{"
    local first=true
    
    for folder in "${!FOLDER_STATES[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            json_content+=","
        fi
        
        local status="${FOLDER_STATES[$folder]}"
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Escape folder path for JSON
        local escaped_folder
        escaped_folder=$(printf '%s' "$folder" | jq -R .)
        
        json_content+="$escaped_folder:{\"status\":\"$status\",\"timestamp\":\"$timestamp\"}"
    done
    
    json_content+="}"
    
    echo "$json_content" > "$STATE_FILE"
    
    # Save categories
    > "$CATEGORIES_FILE"
    for folder in "${!FOLDER_CATEGORIES[@]}"; do
        echo "$folder|${FOLDER_CATEGORIES[$folder]}" >> "$CATEGORIES_FILE"
    done
    
    # Update checkpoint timestamp
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$CHECKPOINT_FILE"
}

# Check if folder is processed
state_is_processed() {
    local folder="$1"
    
    [[ -n "${FOLDER_STATES[$folder]:-}" ]]
}

# Get folder status
state_get_status() {
    local folder="$1"
    
    echo "${FOLDER_STATES[$folder]:-unknown}"
}

# Mark folder as completed
state_mark_completed() {
    local folder="$1"
    
    FOLDER_STATES["$folder"]="completed"
    log_debug "Marked as completed: $folder"
}

# Mark folder as skipped
state_mark_skipped() {
    local folder="$1"
    
    FOLDER_STATES["$folder"]="skipped"
    log_debug "Marked as skipped: $folder"
}

# Mark folder as failed
state_mark_failed() {
    local folder="$1"
    local reason="${2:-unknown error}"
    
    FOLDER_STATES["$folder"]="failed:$reason"
    log_debug "Marked as failed: $folder ($reason)"
}

# Mark folder as deleted
state_mark_deleted() {
    local folder="$1"
    
    FOLDER_STATES["$folder"]="deleted"
    log_debug "Marked as deleted: $folder"
}

# Categorize folder
categorize_folder() {
    local folder="$1"
    local category="$2"
    
    FOLDER_CATEGORIES["$folder"]="$category"
    log_debug "Categorized $folder as: $category"
}

# Get folder category
get_folder_category() {
    local folder="$1"
    
    echo "${FOLDER_CATEGORIES[$folder]:-unknown}"
}

# Get statistics
state_get_statistics() {
    local total=0
    local completed=0
    local skipped=0
    local failed=0
    local deleted=0
    
    for folder in "${!FOLDER_STATES[@]}"; do
        ((total++))
        
        local status="${FOLDER_STATES[$folder]}"
        case "$status" in
            completed)
                ((completed++))
                ;;
            skipped)
                ((skipped++))
                ;;
            failed*)
                ((failed++))
                ;;
            deleted)
                ((deleted++))
                ;;
        esac
    done
    
    echo "total=$total|completed=$completed|skipped=$skipped|failed=$failed|deleted=$deleted"
}

# Generate summary report
generate_summary_report() {
    local report_file="$STATE_DIR/report_$(date +'%Y%m%d_%H%M%S').txt"
    
    log_info "Generating summary report: $report_file"
    
    {
        echo "======================================"
        echo "Mac Cleanup Summary Report"
        echo "Generated: $(date)"
        echo "======================================"
        echo ""
        
        # Statistics
        local stats
        stats=$(state_get_statistics)
        
        local total completed skipped failed deleted
        IFS='|' read -r total completed skipped failed deleted <<< "$stats"
        
        total=${total#total=}
        completed=${completed#completed=}
        skipped=${skipped#skipped=}
        failed=${failed#failed=}
        deleted=${deleted#deleted=}
        
        echo "Statistics:"
        echo "  Total folders processed: $total"
        echo "  Completed: $completed"
        echo "  Skipped: $skipped"
        echo "  Failed: $failed"
        echo "  Deleted: $deleted"
        echo ""
        
        # Category breakdown
        echo "Category Breakdown:"
        echo "-----------------------------------"
        
        declare -A category_counts
        for folder in "${!FOLDER_CATEGORIES[@]}"; do
            local category="${FOLDER_CATEGORIES[$folder]}"
            ((category_counts[$category]++))
        done
        
        for category in "${!category_counts[@]}"; do
            echo "  $category: ${category_counts[$category]}"
        done
        echo ""
        
        # Detailed list
        echo "Detailed Folder List:"
        echo "-----------------------------------"
        
        for folder in "${!FOLDER_STATES[@]}"; do
            local status="${FOLDER_STATES[$folder]}"
            local category="${FOLDER_CATEGORIES[$folder]:-unknown}"
            
            echo "[$status] $(basename "$folder") ($category)"
        done
        
        echo ""
        echo "======================================"
        echo "End of Report"
        echo "======================================"
        
    } > "$report_file"
    
    log_success "Report saved to: $report_file"
    
    # Also create a CSV for easy analysis
    local csv_file="${report_file%.txt}.csv"
    {
        echo "Folder,Status,Category,Path"
        for folder in "${!FOLDER_STATES[@]}"; do
            local status="${FOLDER_STATES[$folder]}"
            local category="${FOLDER_CATEGORIES[$folder]:-unknown}"
            local folder_name
            folder_name=$(basename "$folder")
            
            echo "\"$folder_name\",\"$status\",\"$category\",\"$folder\""
        done
    } > "$csv_file"
    
    log_success "CSV report saved to: $csv_file"
}

# Export state directory location
export STATE_DIR

# Export functions
export -f state_init state_reset state_can_resume state_load
export -f state_save_checkpoint state_is_processed state_get_status
export -f state_mark_completed state_mark_skipped state_mark_failed state_mark_deleted
export -f categorize_folder get_folder_category
export -f state_get_statistics generate_summary_report