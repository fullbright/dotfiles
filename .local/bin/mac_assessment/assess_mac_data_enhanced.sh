#!/bin/bash
#
# Enhanced Mac Data Assessment Script
# Now with: custom directories, office files, encryption, and FTP upload
#

set -euo pipefail

# Source configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Report directory
REPORT_DIR="${HOME}/mac_assessment_report_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${REPORT_DIR}"
LOG_FILE="${REPORT_DIR}/assessment.log"

# Functions
print_status() {
    local color=$1; shift
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

print_section() {
    echo "" | tee -a "${LOG_FILE}"
    echo "═══════════════════════════════════════════════════════════════" | tee -a "${LOG_FILE}"
    print_status "${BLUE}" "$*"
    echo "═══════════════════════════════════════════════════════════════" | tee -a "${LOG_FILE}"
}

print_info() { print_status "${GREEN}" "✓ $*"; }
print_warning() { print_status "${YELLOW}" "⚠ $*"; }
print_error() { print_status "${RED}" "✗ $*"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
get_dir_size() { [[ -d "$1" ]] && du -sh "$1" 2>/dev/null | cut -f1 || echo "N/A"; }
count_files() { [[ -d "$1" ]] && find "$1" -type f 2>/dev/null | wc -l | tr -d ' ' || echo "0"; }

#############################################################################
# INTERACTIVE DIRECTORY CONFIGURATION
#############################################################################

configure_custom_directories() {
    print_section "CUSTOM DIRECTORY CONFIGURATION"

    echo ""
    echo "The script will search common directories for git repositories."
    echo "Do you have repositories in other locations? (y/n)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter additional directories to search (one per line)"
        echo "Press ENTER on empty line when done:"
        echo ""

        local custom_dirs=()
        while true; do
            read -r -p "Directory path: " dir_path
            if [[ -z "$dir_path" ]]; then
                break
            fi

            # Expand tilde
            dir_path="${dir_path/#\~/$HOME}"

            if [[ -d "$dir_path" ]]; then
                custom_dirs+=("$dir_path")
                print_info "Added: $dir_path"
            else
                print_warning "Directory not found: $dir_path (skipping)"
            fi
        done

        CUSTOM_GIT_SEARCH_DIRS=("${custom_dirs[@]}")
    fi

    echo ""
    echo "Do you want to search for office files in specific locations? (y/n)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter directories to search for office files (one per line)"
        echo "Press ENTER on empty line when done:"
        echo ""

        local custom_office_dirs=()
        while true; do
            read -r -p "Directory path: " dir_path
            if [[ -z "$dir_path" ]]; then
                break
            fi

            dir_path="${dir_path/#\~/$HOME}"

            if [[ -d "$dir_path" ]]; then
                custom_office_dirs+=("$dir_path")
                print_info "Added: $dir_path"
            else
                print_warning "Directory not found: $dir_path (skipping)"
            fi
        done

        CUSTOM_OFFICE_SEARCH_DIRS=("${custom_office_dirs[@]}")
    fi
}

#############################################################################
# OFFICE FILES ASSESSMENT
#############################################################################

assess_office_files() {
    print_section "OFFICE FILES ASSESSMENT"
    local output="${REPORT_DIR}/14_office_files.txt"

    print_info "Scanning for office documents (PDF, Word, Excel, PowerPoint)..."

    {
        echo "=== Office Files Inventory ==="
        echo "Scan Date: $(date)"
        echo ""

        # Directories to search
        local search_dirs=(
            "${HOME}/Documents"
            "${HOME}/Desktop"
            "${HOME}/Downloads"
        )

        # Add custom directories
        if [[ ${#CUSTOM_OFFICE_SEARCH_DIRS[@]} -gt 0 ]]; then
            search_dirs+=("${CUSTOM_OFFICE_SEARCH_DIRS[@]}")
        fi

        # File patterns
        local pdf_count=0
        local word_count=0
        local excel_count=0
        local powerpoint_count=0
        local total_size=0

        echo "━━━ PDF Files ━━━"
        for dir in "${search_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then continue; fi

            echo ""
            echo "Searching: $dir"

            local pdf_files
            pdf_files=$(find "$dir" -type f -name "*.pdf" 2>/dev/null | head -100)

            if [[ -n "$pdf_files" ]]; then
                while IFS= read -r file; do
                    ((pdf_count++))
                    local size
                    size=$(du -h "$file" 2>/dev/null | cut -f1)
                    echo "  [$pdf_count] $file ($size)"
                done <<< "$pdf_files"
            fi
        done
        echo ""
        echo "Total PDF files: $pdf_count"
        echo ""

        echo "━━━ Microsoft Word Documents ━━━"
        for dir in "${search_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then continue; fi

            echo ""
            echo "Searching: $dir"

            local word_files
            word_files=$(find "$dir" -type f \( -name "*.doc" -o -name "*.docx" \) 2>/dev/null | head -100)

            if [[ -n "$word_files" ]]; then
                while IFS= read -r file; do
                    ((word_count++))
                    local size
                    size=$(du -h "$file" 2>/dev/null | cut -f1)
                    echo "  [$word_count] $file ($size)"
                done <<< "$word_files"
            fi
        done
        echo ""
        echo "Total Word documents: $word_count"
        echo ""

        echo "━━━ Microsoft Excel Spreadsheets ━━━"
        for dir in "${search_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then continue; fi

            echo ""
            echo "Searching: $dir"

            local excel_files
            excel_files=$(find "$dir" -type f \( -name "*.xls" -o -name "*.xlsx" \) 2>/dev/null | head -100)

            if [[ -n "$excel_files" ]]; then
                while IFS= read -r file; do
                    ((excel_count++))
                    local size
                    size=$(du -h "$file" 2>/dev/null | cut -f1)
                    echo "  [$excel_count] $file ($size)"
                done <<< "$excel_files"
            fi
        done
        echo ""
        echo "Total Excel spreadsheets: $excel_count"
        echo ""

        echo "━━━ Microsoft PowerPoint Presentations ━━━"
        for dir in "${search_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then continue; fi

            echo ""
            echo "Searching: $dir"

            local ppt_files
            ppt_files=$(find "$dir" -type f \( -name "*.ppt" -o -name "*.pptx" \) 2>/dev/null | head -100)

            if [[ -n "$ppt_files" ]]; then
                while IFS= read -r file; do
                    ((powerpoint_count++))
                    local size
                    size=$(du -h "$file" 2>/dev/null | cut -f1)
                    echo "  [$powerpoint_count] $file ($size)"
                done <<< "$ppt_files"
            fi
        done
        echo ""
        echo "Total PowerPoint files: $powerpoint_count"
        echo ""

        echo "═══════════════════════════════════════════════════════════"
        echo "OFFICE FILES SUMMARY"
        echo "═══════════════════════════════════════════════════════════"
        echo "PDF files: $pdf_count"
        echo "Word documents: $word_count"
        echo "Excel spreadsheets: $excel_count"
        echo "PowerPoint presentations: $powerpoint_count"
        echo "Total office files: $((pdf_count + word_count + excel_count + powerpoint_count))"
        echo ""
        echo "⚠️  IMPORTANT: Large office file directories should be backed up!"
        echo ""

        # Calculate total size of office files
        echo "━━━ Office Files by Directory Size ━━━"
        for dir in "${search_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then continue; fi

            local office_size
            office_size=$(find "$dir" -type f \( -name "*.pdf" -o -name "*.doc" -o -name "*.docx" -o -name "*.xls" -o -name "*.xlsx" -o -name "*.ppt" -o -name "*.pptx" \) -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1 || echo "0")

            if [[ "$office_size" != "0" ]]; then
                echo "$dir: $office_size"
            fi
        done

    } > "$output"

    print_info "Office files assessment saved to: $output"
}

#############################################################################
# ENHANCED GIT REPOSITORIES WITH CUSTOM DIRS
#############################################################################

assess_git_repos_enhanced() {
    print_section "GIT REPOSITORIES (ENHANCED)"
    local output="${REPORT_DIR}/02_git_repositories_enhanced.txt"

    print_info "Scanning for git repositories (including custom directories)..."

    # Standard directories
    local search_dirs=(
        "${HOME}/Documents"
        "${HOME}/Desktop"
        "${HOME}/Projects"
        "${HOME}/Dev"
        "${HOME}/Development"
        "${HOME}/Code"
        "${HOME}/src"
        "${HOME}/repos"
        "${HOME}/git"
        "${HOME}/dotfiles"
    )

    # Add custom directories from config
    if [[ ${#CUSTOM_GIT_SEARCH_DIRS[@]} -gt 0 ]]; then
        search_dirs+=("${CUSTOM_GIT_SEARCH_DIRS[@]}")
    fi

    {
        echo "=== Enhanced Git Repository Scan ==="
        echo "Scan Date: $(date)"
        echo ""
        echo "Searching in:"
        for dir in "${search_dirs[@]}"; do
            echo "  - $dir"
        done
        echo ""

        local repo_count=0
        local repos_with_changes=0
        local repos_with_unpushed=0
        local repos_clean=0

        for base_dir in "${search_dirs[@]}"; do
            if [[ ! -d "$base_dir" ]]; then
                continue
            fi

            echo ""
            echo "━━━ Scanning: $base_dir ━━━"
            echo ""

            while IFS= read -r -d '' git_dir; do
                repo_dir=$(dirname "$git_dir")
                ((repo_count++))

                echo "[$repo_count] Repository: $repo_dir"
                echo "    Size: $(get_dir_size "$repo_dir")"

                cd "$repo_dir" || continue

                local remotes
                remotes=$(git remote -v 2>/dev/null | grep fetch | awk '{print $2}' || echo "No remotes")
                echo "    Remote: $remotes"

                local branch
                branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
                echo "    Branch: $branch"

                if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                    echo "    Status: ⚠️  HAS UNCOMMITTED CHANGES"
                    ((repos_with_changes++))
                    echo "    Modified files:"
                    git status --short | head -20
                else
                    echo "    Status: ✓ Clean working directory"
                    ((repos_clean++))
                fi

                if [[ "$remotes" != "No remotes" ]]; then
                    local unpushed
                    unpushed=$(git log @{u}.. --oneline 2>/dev/null | wc -l | tr -d ' ')
                    if [[ $unpushed -gt 0 ]]; then
                        echo "    Unpushed: ⚠️  $unpushed commit(s) not pushed"
                        ((repos_with_unpushed++))
                    fi
                fi

                echo ""
            done < <(find "$base_dir" -name ".git" -type d -print0 2>/dev/null)
        done

        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "SUMMARY"
        echo "═══════════════════════════════════════════════════════════"
        echo "Total repositories found: $repo_count"
        echo "Repositories with uncommitted changes: $repos_with_changes"
        echo "Repositories with unpushed commits: $repos_with_unpushed"
        echo "Clean repositories: $repos_clean"

    } > "$output"

    print_info "Enhanced git scan complete: $repo_count repositories found"
    if [[ $repos_with_changes -gt 0 ]]; then
        print_warning "$repos_with_changes repositories have uncommitted changes!"
    fi
}

#############################################################################
# ENHANCED DUPLICATE DETECTION
#############################################################################

assess_duplicates_enhanced() {
    print_section "ENHANCED DUPLICATE FILE DETECTION"
    local output="${REPORT_DIR}/15_duplicates_enhanced.txt"

    print_info "Analyzing duplicates and overlapping folders..."

    {
        echo "=== Enhanced Duplicate and Overlap Analysis ==="
        echo ""

        echo "━━━ Finding Duplicate Filenames ━━━"
        echo "Files with same name in different locations:"
        echo ""

        # Find files with same name
        find "${HOME}/Documents" "${HOME}/Desktop" "${HOME}/Downloads" -type f 2>/dev/null | \
            awk -F/ '{print $NF, $0}' | \
            sort | \
            awk '{name=$1; $1=""; files[name]=files[name] $0 "\n"} END {for(n in files) if(gsub(/\n/,"\n",files[n])>1) print "Duplicate name: " n "\n" files[n]}' | \
            head -100

        echo ""
        echo "━━━ Backup-like Folder Patterns ━━━"
        echo ""

        # Find backup folders
        find "${HOME}" -maxdepth 3 -type d \( \
            -name "*backup*" -o \
            -name "*Backup*" -o \
            -name "*old*" -o \
            -name "*OLD*" -o \
            -name "*archive*" -o \
            -name "*Archive*" -o \
            -name "*copy*" -o \
            -name "*Copy*" \
        \) 2>/dev/null | while read -r dir; do
            echo "Found: $dir"
            echo "  Size: $(get_dir_size "$dir")"
            echo "  Files: $(count_files "$dir")"
            echo ""
        done

        echo "━━━ Recommendations for Deduplication ━━━"
        echo ""
        echo "1. Review backup-like folders and consolidate"
        echo "2. Use 'diff' or 'rsync --dry-run' to compare folders"
        echo "3. Consider using a deduplication tool like 'fdupes'"
        echo "4. Archive old backups to external storage"
        echo ""

    } > "$output"

    print_info "Duplicate analysis saved to: $output"
}

#############################################################################
# ENCRYPTION AND FTP UPLOAD
#############################################################################

encrypt_and_upload() {
    print_section "ENCRYPTION AND FTP UPLOAD"

    if [[ "${ENCRYPT_BACKUP:-false}" != "true" ]] && [[ "${FTP_ENABLED:-false}" != "true" ]]; then
        print_info "Encryption and FTP upload are disabled in config.sh"
        return
    fi

    local backup_archive="${REPORT_DIR}.tar.gz"

    # Create archive
    print_info "Creating archive: $backup_archive"
    tar -czf "$backup_archive" -C "$(dirname "$REPORT_DIR")" "$(basename "$REPORT_DIR")"

    # Encrypt if enabled
    if [[ "${ENCRYPT_BACKUP:-false}" == "true" ]]; then
        print_info "Encrypting backup..."

        if [[ -n "${GPG_RECIPIENT:-}" ]]; then
            # GPG encryption
            gpg --encrypt --recipient "$GPG_RECIPIENT" "$backup_archive"
            local encrypted_file="${backup_archive}.gpg"
            print_info "Encrypted to: $encrypted_file"
            backup_archive="$encrypted_file"
        elif [[ -n "${ENCRYPTION_PASSWORD:-}" ]]; then
            # Password-based encryption
            gpg --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_PASSWORD" "$backup_archive"
            local encrypted_file="${backup_archive}.gpg"
            print_info "Encrypted to: $encrypted_file"
            rm "$backup_archive"  # Remove unencrypted
            backup_archive="$encrypted_file"
        else
            print_warning "Encryption enabled but no GPG_RECIPIENT or ENCRYPTION_PASSWORD set!"
        fi
    fi

    # Upload via FTP if enabled
    if [[ "${FTP_ENABLED:-false}" == "true" ]]; then
        print_info "Uploading to FTP server..."

        if command_exists lftp; then
            lftp -u "${FTP_USER},${FTP_PASS}" "${FTP_HOST}" <<EOF
set ftp:port ${FTP_PORT}
cd ${FTP_REMOTE_DIR}
put ${backup_archive}
bye
EOF
            print_info "Upload complete!"
        elif command_exists curl; then
            curl -T "$backup_archive" -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_HOST}:${FTP_PORT}/${FTP_REMOTE_DIR}/"
            print_info "Upload complete!"
        else
            print_error "Neither lftp nor curl found. Cannot upload to FTP."
            print_info "Install with: brew install lftp"
        fi
    fi
}

#############################################################################
# MAIN EXECUTION
#############################################################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           ENHANCED MAC DATA ASSESSMENT TOOL                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Interactive configuration
    configure_custom_directories

    print_info "Starting enhanced assessment..."
    print_info "Report directory: ${REPORT_DIR}"
    echo ""

    # Run assessments
    assess_git_repos_enhanced
    assess_office_files
    assess_duplicates_enhanced

    # Source original script functions for remaining assessments
    # (You would call the original assess functions here)

    print_section "ASSESSMENT COMPLETE"
    echo ""
    print_info "Reports saved to: ${REPORT_DIR}"
    echo ""

    # Encryption and upload
    encrypt_and_upload

    print_status "${GREEN}" "════════════════════════════════════════════════════════════════"
    print_status "${GREEN}" "Review reports and use the PRE_REINSTALL_CHECKLIST.md"
    print_status "${GREEN}" "════════════════════════════════════════════════════════════════"
    echo ""
}

main "$@"
