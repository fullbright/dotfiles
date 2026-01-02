#!/usr/bin/env bash
#
# Deduplication Helper Script
# Helps find and handle duplicate files and overlapping folders
#

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() { echo -e "${GREEN}✓${NC} $*"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
print_error() { echo -e "${RED}✗${NC} $*"; }

#############################################################################
# MENU
#############################################################################

show_menu() {
    clear
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           DEDUPLICATION HELPER                                ║"
    echo "║           Handle Duplicates and Overlapping Folders           ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  1) Find exact duplicate files (same content)"
    echo "  2) Find files with duplicate names (different locations)"
    echo "  3) Find backup-like folders"
    echo "  4) Compare two folders"
    echo "  5) Consolidate backup folders"
    echo "  6) Generate deduplication report"
    echo "  0) Exit"
    echo ""
    read -rp "Enter choice [0-6]: " choice
}

#############################################################################
# FIND EXACT DUPLICATES
#############################################################################

find_exact_duplicates() {
    print_header "Find Exact Duplicate Files"

    read -rp "Enter directory to scan (e.g., ~/Documents): " scan_dir
    scan_dir="${scan_dir/#\~/$HOME}"

    if [[ ! -d "$scan_dir" ]]; then
        print_error "Directory not found: $scan_dir"
        return
    fi

    print_info "Scanning for duplicates in: $scan_dir"
    print_warning "This may take several minutes for large directories..."

    if command -v fdupes >/dev/null 2>&1; then
        local output_file="${HOME}/Desktop/duplicates_$(date +%Y%m%d_%H%M%S).txt"

        fdupes -r "$scan_dir" > "$output_file"

        print_info "Results saved to: $output_file"
        echo ""
        echo "Summary:"
        local dup_count
        dup_count=$(grep -c "^$" "$output_file" || echo "0")
        echo "  Duplicate groups found: $dup_count"
        echo ""

        read -rp "Do you want to delete duplicates interactively? (y/n): " delete_choice
        if [[ "$delete_choice" =~ ^[Yy]$ ]]; then
            echo ""
            print_warning "You will be prompted for each duplicate group"
            print_warning "Press ENTER to keep all, or select files to delete"
            echo ""
            read -rp "Continue? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                fdupes -r -d "$scan_dir"
            fi
        fi
    else
        print_error "fdupes not installed"
        echo ""
        echo "Install with: brew install fdupes"
        echo ""
        echo "Alternative: Using find and md5sum (slower)"
        read -rp "Use alternative method? (y/n): " alt_choice
        if [[ "$alt_choice" =~ ^[Yy]$ ]]; then
            find "$scan_dir" -type f -exec md5 {} \; | \
                sort | \
                awk '{hash=$4; $1=$2=$3=$4=""; file=$0; if(hash==prev_hash) print prev_file "\n" file; prev_hash=hash; prev_file=file}' > \
                "${HOME}/Desktop/duplicates_$(date +%Y%m%d_%H%M%S).txt"

            print_info "Results saved to Desktop"
        fi
    fi

    echo ""
    read -rp "Press ENTER to continue..."
}

#############################################################################
# FIND DUPLICATE NAMES
#############################################################################

find_duplicate_names() {
    print_header "Find Files with Duplicate Names"

    read -rp "Enter directory to scan (e.g., ~/Documents): " scan_dir
    scan_dir="${scan_dir/#\~/$HOME}"

    if [[ ! -d "$scan_dir" ]]; then
        print_error "Directory not found: $scan_dir"
        return
    fi

    print_info "Scanning for duplicate names in: $scan_dir"

    local output_file="${HOME}/Desktop/duplicate_names_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== Files with Duplicate Names ==="
        echo "Generated: $(date)"
        echo ""

        find "$scan_dir" -type f -print0 2>/dev/null | \
            xargs -0 -n1 basename | \
            sort | \
            uniq -d | \
            while read -r filename; do
                echo "━━━ Duplicate name: $filename ━━━"
                find "$scan_dir" -type f -name "$filename" -print
                echo ""
            done
    } > "$output_file"

    print_info "Results saved to: $output_file"

    echo ""
    echo "Preview (first 50 lines):"
    head -50 "$output_file"

    echo ""
    read -rp "Press ENTER to continue..."
}

#############################################################################
# FIND BACKUP FOLDERS
#############################################################################

find_backup_folders() {
    print_header "Find Backup-Like Folders"

    print_info "Scanning home directory for backup folders..."

    local output_file="${HOME}/Desktop/backup_folders_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== Backup-Like Folders ==="
        echo "Generated: $(date)"
        echo ""

        find "${HOME}" -maxdepth 3 -type d \( \
            -iname "*backup*" -o \
            -iname "*old*" -o \
            -iname "*archive*" -o \
            -iname "*copy*" -o \
            -iname "*.bak" -o \
            -iname "*_bak" -o \
            -iname "*-old" \
        \) 2>/dev/null | while read -r dir; do
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)

            local file_count
            file_count=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Folder: $dir"
            echo "Size: $size"
            echo "Files: $file_count"
            echo ""
        done
    } > "$output_file"

    print_info "Results saved to: $output_file"

    echo ""
    cat "$output_file"

    echo ""
    read -rp "Press ENTER to continue..."
}

#############################################################################
# COMPARE TWO FOLDERS
#############################################################################

compare_folders() {
    print_header "Compare Two Folders"

    read -rp "Enter first folder path: " folder1
    folder1="${folder1/#\~/$HOME}"

    read -rp "Enter second folder path: " folder2
    folder2="${folder2/#\~/$HOME}"

    if [[ ! -d "$folder1" ]]; then
        print_error "Folder not found: $folder1"
        return
    fi

    if [[ ! -d "$folder2" ]]; then
        print_error "Folder not found: $folder2"
        return
    fi

    print_info "Comparing folders..."
    echo ""

    local output_file="${HOME}/Desktop/folder_comparison_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=== Folder Comparison ==="
        echo "Folder 1: $folder1"
        echo "Folder 2: $folder2"
        echo "Generated: $(date)"
        echo ""

        echo "━━━ Size Comparison ━━━"
        echo "Folder 1 size: $(du -sh "$folder1" | cut -f1)"
        echo "Folder 2 size: $(du -sh "$folder2" | cut -f1)"
        echo ""

        echo "━━━ File Count ━━━"
        echo "Folder 1 files: $(find "$folder1" -type f | wc -l)"
        echo "Folder 2 files: $(find "$folder2" -type f | wc -l)"
        echo ""

        echo "━━━ Files only in Folder 1 ━━━"
        comm -23 \
            <(cd "$folder1" && find . -type f | sort) \
            <(cd "$folder2" && find . -type f | sort)
        echo ""

        echo "━━━ Files only in Folder 2 ━━━"
        comm -13 \
            <(cd "$folder1" && find . -type f | sort) \
            <(cd "$folder2" && find . -type f | sort)
        echo ""

        echo "━━━ Common Files ━━━"
        comm -12 \
            <(cd "$folder1" && find . -type f | sort) \
            <(cd "$folder2" && find . -type f | sort)
        echo ""

    } > "$output_file"

    print_info "Comparison saved to: $output_file"

    echo ""
    echo "Do you want to see differences in detail? (using diff)"
    read -rp "(y/n): " diff_choice

    if [[ "$diff_choice" =~ ^[Yy]$ ]]; then
        echo ""
        print_info "Running diff (this may take a while)..."
        diff -r "$folder1" "$folder2" | tee -a "$output_file"
    fi

    echo ""
    read -rp "Press ENTER to continue..."
}

#############################################################################
# CONSOLIDATE BACKUP FOLDERS
#############################################################################

consolidate_backups() {
    print_header "Consolidate Backup Folders"

    echo "This will help you merge multiple backup folders into one"
    echo ""

    read -rp "Enter destination folder (will be created if doesn't exist): " dest_folder
    dest_folder="${dest_folder/#\~/$HOME}"

    mkdir -p "$dest_folder"

    print_info "Destination: $dest_folder"
    echo ""
    echo "Now enter source folders to merge (one per line, empty line to finish):"

    local source_folders=()
    while true; do
        read -rp "Source folder: " source
        if [[ -z "$source" ]]; then
            break
        fi

        source="${source/#\~/$HOME}"

        if [[ ! -d "$source" ]]; then
            print_warning "Not found: $source (skipping)"
            continue
        fi

        source_folders+=("$source")
        print_info "Added: $source"
    done

    if [[ ${#source_folders[@]} -eq 0 ]]; then
        print_error "No source folders specified"
        return
    fi

    echo ""
    echo "Summary:"
    echo "  Destination: $dest_folder"
    echo "  Sources:"
    for src in "${source_folders[@]}"; do
        echo "    - $src"
    done

    echo ""
    echo "⚠️  This will:"
    echo "  - Copy all files to destination"
    echo "  - Skip existing files (won't overwrite)"
    echo "  - Preserve directory structure"
    echo ""

    read -rp "Proceed? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        return
    fi

    # DRY RUN first
    echo ""
    print_info "DRY RUN - showing what would be copied..."
    for src in "${source_folders[@]}"; do
        echo ""
        echo "From: $src"
        rsync -av --dry-run --ignore-existing "$src/" "$dest_folder/" | grep -v "^$" | head -20
    done

    echo ""
    read -rp "Looks good? Proceed with actual copy? (y/n): " final_confirm

    if [[ "$final_confirm" =~ ^[Yy]$ ]]; then
        for src in "${source_folders[@]}"; do
            print_info "Copying from: $src"
            rsync -av --progress --ignore-existing "$src/" "$dest_folder/"
        done

        print_info "Consolidation complete!"
        echo ""
        echo "New consolidated folder: $dest_folder"
        echo "Size: $(du -sh "$dest_folder" | cut -f1)"
        echo ""
        echo "⚠️  Remember to:"
        echo "  1. Verify the consolidated folder has everything"
        echo "  2. Archive or delete the old backup folders"
    else
        print_info "Cancelled"
    fi

    echo ""
    read -rp "Press ENTER to continue..."
}

#############################################################################
# GENERATE REPORT
#############################################################################

generate_report() {
    print_header "Generate Deduplication Report"

    local report_file="${HOME}/Desktop/deduplication_report_$(date +%Y%m%d_%H%M%S).txt"

    print_info "Generating comprehensive report..."
    print_warning "This will scan Documents, Desktop, and Downloads"
    echo ""

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║                                                               ║"
        echo "║           DEDUPLICATION REPORT                                ║"
        echo "║                                                               ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date)"
        echo ""

        # Disk usage
        echo "━━━ Disk Usage ━━━"
        df -h /
        echo ""

        # Large directories
        echo "━━━ Top 20 Largest Directories in Home ━━━"
        du -h "${HOME}" 2>/dev/null | sort -rh | head -20
        echo ""

        # Backup folders
        echo "━━━ Backup-Like Folders ━━━"
        find "${HOME}" -maxdepth 3 -type d \( \
            -iname "*backup*" -o \
            -iname "*old*" -o \
            -iname "*archive*" \
        \) 2>/dev/null | while read -r dir; do
            echo "$dir ($(du -sh "$dir" 2>/dev/null | cut -f1))"
        done
        echo ""

        # Large files
        echo "━━━ Files Larger than 100MB ━━━"
        find "${HOME}" -type f -size +100M 2>/dev/null -exec du -h {} \; | sort -rh | head -30
        echo ""

        # Duplicate names count
        echo "━━━ Files with Duplicate Names (top 20) ━━━"
        find "${HOME}/Documents" "${HOME}/Desktop" "${HOME}/Downloads" -type f 2>/dev/null | \
            xargs -n1 basename 2>/dev/null | \
            sort | \
            uniq -d | \
            head -20
        echo ""

        # Recommendations
        echo "━━━ Recommendations ━━━"
        echo ""
        echo "1. Review backup-like folders and consolidate or archive"
        echo "2. Run exact duplicate scan to find redundant files"
        echo "3. Move large files (>100MB) to external storage if not needed"
        echo "4. Check for old Downloads folder items"
        echo "5. Use Time Machine or cloud backup for important data"
        echo ""

    } > "$report_file"

    print_info "Report saved to: $report_file"
    echo ""
    cat "$report_file"

    echo ""
    read -rp "Press ENTER to continue..."
}

#############################################################################
# MAIN
#############################################################################

main() {
    while true; do
        show_menu

        case $choice in
            1) find_exact_duplicates ;;
            2) find_duplicate_names ;;
            3) find_backup_folders ;;
            4) compare_folders ;;
            5) consolidate_backups ;;
            6) generate_report ;;
            0) echo ""; print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

main "$@"
