#!/usr/local/bin/bash
#
# Mac Data Assessment Script
# Purpose: Comprehensive inventory of all data before Mac reinstallation
# Author: Generated for Mac backup assessment
# Date: 2025-11-06
#
# This script performs READ-ONLY operations to assess your Mac's data
# It generates a detailed report in ~/mac_assessment_report/
#

set -euo pipefail

# Source configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Report directory
REPORT_DIR="${HOME}/mac_assessment_report_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${REPORT_DIR}"

# Log file
LOG_FILE="${REPORT_DIR}/assessment.log"

# Function to print colored output
print_status() {
    local color=$1
    shift
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

print_section() {
    echo "" | tee -a "${LOG_FILE}"
    echo "═══════════════════════════════════════════════════════════════" | tee -a "${LOG_FILE}"
    print_status "${BLUE}" "$*"
    echo "═══════════════════════════════════════════════════════════════" | tee -a "${LOG_FILE}"
}

print_info() {
    print_status "${GREEN}" "✓ $*"
}

print_warning() {
    print_status "${YELLOW}" "⚠ $*"
}

print_error() {
    print_status "${RED}" "✗ $*"
}

# Function to safely check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get directory size in human-readable format
get_dir_size() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        du -sh "$dir" 2>/dev/null | cut -f1 || echo "N/A"
    else
        echo "N/A"
    fi
}

# Function to count files in directory
count_files() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        find "$dir" -type f 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

#############################################################################
# SYSTEM INFORMATION
#############################################################################

assess_system_info() {
    print_section "SYSTEM INFORMATION"
    local output="${REPORT_DIR}/01_system_info.txt"

    {
        echo "=== System Information ==="
        echo ""
        echo "Hostname: $(hostname)"
        echo "macOS Version: $(sw_vers -productVersion)"
        echo "Build Version: $(sw_vers -buildVersion)"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "User: $(whoami)"
        echo "Home Directory: ${HOME}"
        echo ""
        echo "=== Disk Usage ==="
        df -h /
        echo ""
        echo "=== Memory ==="
        sysctl hw.memsize | awk '{print "Total RAM: " $2/1073741824 " GB"}'
        echo ""
        echo "=== Current Date/Time ==="
        date
    } > "$output"

    print_info "System information saved to: $output"
}

#############################################################################
# GIT REPOSITORIES
#############################################################################

assess_git_repos() {
    print_section "GIT REPOSITORIES ASSESSMENT"
    local output="${REPORT_DIR}/02_git_repositories.txt"
    local json_output="${REPORT_DIR}/02_git_repositories.json"

    print_info "Scanning for git repositories in common locations..."

    # Common directories to scan - start with smaller set
    local search_dirs=(
        "${HOME}/Desktop"
        "${HOME}/Documents"
    )
    
    # Add more directories if they exist and are accessible
    [[ -d "${HOME}/Projects" && -r "${HOME}/Projects" ]] && search_dirs+=("${HOME}/Projects")
    [[ -d "${HOME}/Dev" && -r "${HOME}/Dev" ]] && search_dirs+=("${HOME}/Dev")
    [[ -d "${HOME}/Development" && -r "${HOME}/Development" ]] && search_dirs+=("${HOME}/Development")
    [[ -d "${HOME}/Code" && -r "${HOME}/Code" ]] && search_dirs+=("${HOME}/Code")
    [[ -d "${HOME}/src" && -r "${HOME}/src" ]] && search_dirs+=("${HOME}/src")
    [[ -d "${HOME}/repos" && -r "${HOME}/repos" ]] && search_dirs+=("${HOME}/repos")
    [[ -d "${HOME}/git" && -r "${HOME}/git" ]] && search_dirs+=("${HOME}/git")
    [[ -d "${HOME}/dotfiles" && -r "${HOME}/dotfiles" ]] && search_dirs+=("${HOME}/dotfiles")
    
    # Add the custom dirs
    # Add custom directories from config
    if [[ ${#CUSTOM_GIT_SEARCH_DIRS[@]} -gt 0 ]]; then
        search_dirs+=("${CUSTOM_GIT_SEARCH_DIRS[@]}")
    fi

    {
        echo "=== Git Repository Inventory ==="
        echo "Scan Date: $(date)"
        echo ""

        local repo_count=0
        local repos_with_changes=0
        local repos_with_unpushed=0
        local repos_clean=0
        
        echo "Processing ${#search_dirs[@]} search dirs"
        echo "Search dirs = ${search_dirs[@]}"

        for base_dir in "${search_dirs[@]}"; do
            [[ -d "$base_dir" ]] || continue

            echo ""
            echo "━━━ Scanning: $base_dir ━━━"
            echo ""

            # First, collect all git directories into an array to avoid pipe issues
            local git_repos=()
            while IFS= read -r git_dir; do
                [[ -n "$git_dir" ]] && git_repos+=("$git_dir")
            done < <(find "$base_dir" -type d -name ".git" 2>/dev/null)
        #done

            echo "Found ${#git_repos[@]} repositories in $base_dir"
            echo "Repos are ${git_repos[@]}"
            echo ""

            # Now process each repository
            for git_dir in "${git_repos[@]}"; do
                echo "Processing git_dir = $git_dir"
                repo_dir=$(dirname "$git_dir")
                echo "Repo dir = $repo_dir"
                repo_count=$((repo_count+1))

                echo "[$repo_count] Repository: $repo_dir"

                # Check basic access first
                if [[ ! -x "$repo_dir" || ! -r "$repo_dir" ]]; then
                    echo "    ⚠️  Skipped (permission denied)"
                    echo ""
                    continue
                fi

                # Try to change to directory
                if ! cd "$repo_dir" 2>/dev/null; then
                    echo "    ⚠️  Cannot enter directory"
                    echo ""
                    continue
                fi

                # Verify it's a valid git repo
                if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                    echo "    ⚠️  Not a valid git repo"
                    echo ""
                    continue
                fi

                # Get directory size
                local size
                size=$(du -sh "$repo_dir" 2>/dev/null | cut -f1 || echo "unknown")
                echo "    Size: $size"

                # Get remote URLs
                local remotes
                remotes=$(git remote -v 2>/dev/null | awk '/fetch/{print $2}' | head -1)
                [[ -z "$remotes" ]] && remotes="No remotes"
                echo "    Remote: $remotes"

                # Get current branch
                local branch
                branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
                echo "    Branch: $branch"

                # Check for uncommitted changes
                local has_changes=0
                if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                    echo "    Status: ⚠️  HAS UNCOMMITTED CHANGES"
                    has_changes=1
                    repos_with_changes=$((repos_with_changes+1))
                    
                    # Show modified files (limited to first 10)
                    echo "    Modified files:"
                    git status --short
                    echo "    Git status (showing top 10):"
                    git status --short 2>/dev/null | head -10
                    
                    echo "    8"
                    local change_count
                    echo "    6"
                    change_count=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
                    echo "    7"
                    if [[ $change_count -gt 10 ]]; then
                        echo "    ... and $((change_count - 10)) more files"
                    fi
                else
                    echo "    Status: ✓ Clean"
                    repos_clean=$((repos_clean+1))
                fi

                # Check for unpushed commits (only if there are remotes)
                echo "    4"
                if [[ "$remotes" != "No remotes" ]]; then
                    echo "    Found remotes $remotes"
                    local unpushed
                    # unpushed=$(git log -c $repo_dir @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ') || true
                    git log --branches --not --remotes --oneline
                    #git log --branches --not --remotes --oneline >/dev/null
#                    echo "Last command result = $?"
#                    if [[ $? != 0 ]] ; then
#                        echo "Git failed to detect unpushed branched. Trying git gc and rename the icon issues."
#                        git gc
#                        if [[ $? != 0 ]] ; then
#                            echo "likely a icon issue generated by google drive sync. run auto fix"
#                            mv .git/**/Icon* /tmp
#                            echo "try git gc again"
#                            if [[ $? != 0 ]] ; then
#                                echo "still failing. Manual check then"
#                            else
#                                echo "git gc success -> issue fixed"
#                            fi
#                        else
#                            echo "git gc success -> not a Icon file google drive issue, check manually"
#                        fi
#                    else
#                        echo "Git unpushed updates succeeded. Continuing."
#                    fi
                    echo "9"
                    unpushed=$(git log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
                    echo "    Found $unpushed unpushed commits"
                    if [[ -n "$unpushed" && $unpushed -gt 0 ]]; then
                        echo "    Unpushed: ⚠️  $unpushed commit(s) not pushed"
                        repos_with_unpushed=$((repos_with_unpushed+1))
                    fi
                fi
                echo "    5"

                # Last commit info
                local last_commit
                last_commit=$(git log -1 --format="%h - %s (%cr)" 2>/dev/null || echo "No commits")
                echo "    Last commit: $last_commit"

                # Check for stashes
                local stash_count
                stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
                if [[ -n "$stash_count" && $stash_count -gt 0 ]]; then
                    echo "    Stashes: ⚠️  $stash_count stashed change(s)"
                fi

                echo "Done with $repo_dir. Continue with next one."
                echo ""
            done
        done
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "SUMMARY"
        echo "═══════════════════════════════════════════════════════════"
        echo "Total repositories found: ${repo_count:-0}"
        echo "Repositories with uncommitted changes: ${repos_with_changes:-0}"
        echo "Repositories with unpushed commits: ${repos_with_unpushed:-0}"
        echo "Clean repositories: ${repos_clean:-0}"
        echo ""

        if [[ ${repos_with_changes:-0} -gt 0 || ${repos_with_unpushed:-0} -gt 0 ]]; then
            echo "⚠️  WARNING: You have repositories that need attention!"
            echo "   Please commit and push changes before reinstalling."
        fi

    } | tee "$output"

    print_info "Git repositories assessed: ${repo_count:-0} repositories found"
    print_info "Details saved to: $output"

    if [[ ${repos_with_changes:-0} -gt 0 ]]; then
        print_warning "${repos_with_changes:-0} repositories have uncommitted changes"
    fi
}

#############################################################################
# HOMEBREW PACKAGES
#############################################################################

assess_homebrew() {
    print_section "HOMEBREW PACKAGES"
    local output="${REPORT_DIR}/03_homebrew_packages.txt"

    if ! command_exists brew; then
        print_warning "Homebrew not installed"
        echo "Homebrew is not installed on this system" > "$output"
        return
    fi

    print_info "Collecting Homebrew package lists..."

    {
        echo "=== Homebrew Installation ==="
        echo ""
        echo "Homebrew Version: $(brew --version | head -1)"
        echo "Homebrew Prefix: $(brew --prefix)"
        echo ""

        echo "=== Installed Formulae ==="
        brew list --formula | sort
        echo ""
        echo "Total Formulae: $(brew list --formula | wc -l | tr -d ' ')"
        echo ""

        echo "=== Installed Casks ==="
        brew list --cask | sort
        echo ""
        echo "Total Casks: $(brew list --cask | wc -l | tr -d ' ')"
        echo ""

        echo "=== Taps ==="
        brew tap
        echo ""

        echo "=== Brew Bundle Dump (Brewfile format) ==="
        brew bundle dump --file=- 2>/dev/null || echo "Could not generate Brewfile"

    } > "$output"

    # Also create a Brewfile for easy restoration
    brew bundle dump --force --file="${REPORT_DIR}/Brewfile" 2>/dev/null || true

    print_info "Homebrew packages saved to: $output"
    if [[ -f "${REPORT_DIR}/Brewfile" ]]; then
        print_info "Brewfile created at: ${REPORT_DIR}/Brewfile"
        print_info "  To restore: brew bundle install --file=${REPORT_DIR}/Brewfile"
    fi
}

#############################################################################
# MAC APP STORE APPLICATIONS
#############################################################################

assess_mac_app_store() {
    print_section "MAC APP STORE APPLICATIONS"
    local output="${REPORT_DIR}/04_mac_app_store.txt"

    if ! command_exists mas; then
        print_warning "mas-cli not installed (install with: brew install mas)"
        {
            echo "mas-cli not installed"
            echo ""
            echo "Install with: brew install mas"
            echo ""
            echo "=== Applications folder ==="
            ls -la /Applications | grep "\.app$" || true
        } > "$output"
        return
    fi

    print_info "Listing Mac App Store applications..."

    {
        echo "=== Mac App Store Applications ==="
        echo ""
        mas list | sort
        echo ""
        echo "Total: $(mas list | wc -l | tr -d ' ') applications"
        echo ""
        echo "=== To reinstall all apps, run: ==="
        echo ""
        mas list | awk '{print "mas install " $1 " # " substr($0, index($0,$2))}'

    } > "$output"

    print_info "Mac App Store applications saved to: $output"
}

#############################################################################
# ALL INSTALLED APPLICATIONS
#############################################################################

assess_all_applications() {
    print_section "ALL INSTALLED APPLICATIONS"
    local output="${REPORT_DIR}/05_all_applications.txt"

    print_info "Scanning /Applications and ~/Applications..."

    {
        echo "=== System Applications (/Applications) ==="
        echo ""
        find /Applications -maxdepth 1 -name "*.app" -type d -exec basename {} \; 2>/dev/null | sort
        echo ""
        echo "Total: $(find /Applications -maxdepth 1 -name "*.app" -type d 2>/dev/null | wc -l | tr -d ' ')"
        echo ""

        echo "=== User Applications (~/Applications) ==="
        echo ""
        if [[ -d "${HOME}/Applications" ]]; then
            find "${HOME}/Applications" -maxdepth 1 -name "*.app" -type d -exec basename {} \; 2>/dev/null | sort
            echo ""
            echo "Total: $(find "${HOME}/Applications" -maxdepth 1 -name "*.app" -type d 2>/dev/null | wc -l | tr -d ' ')"
        else
            echo "No user Applications directory"
        fi

    } > "$output"

    print_info "Applications list saved to: $output"
}

#############################################################################
# BROWSER PROFILES
#############################################################################

assess_browser_profiles() {
    print_section "BROWSER PROFILES"
    local output="${REPORT_DIR}/06_browser_profiles.txt"

    print_info "Scanning for browser profiles..."

    {
        echo "=== Browser Profiles ==="
        echo ""

        # Google Chrome
        echo "━━━ Google Chrome ━━━"
        local chrome_dir="${HOME}/Library/Application Support/Google/Chrome"
        if [[ -d "$chrome_dir" ]]; then
            echo "Chrome directory: $chrome_dir"
            echo "Size: $(get_dir_size "$chrome_dir")"
            echo "Profiles found:"
            find "$chrome_dir" -maxdepth 1 -type d -name "Profile*" -o -name "Default" | while read -r profile; do
                local profile_name=$(basename "$profile")
                echo "  - $profile_name ($(get_dir_size "$profile"))"

                # Check for Preferences file
                if [[ -f "$profile/Preferences" ]]; then
                    echo "    Has Preferences file: Yes"
                    # Try to extract profile name from Preferences
                    if command_exists jq; then
                        local display_name
                        display_name=$(jq -r '.profile.name // "N/A"' "$profile/Preferences" 2>/dev/null || echo "N/A")
                        echo "    Display Name: $display_name"
                    fi
                fi

                # Count extensions
                local ext_dir="$profile/Extensions"
                if [[ -d "$ext_dir" ]]; then
                    local ext_count
                    ext_count=$(find "$ext_dir" -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')
                    echo "    Extensions: $ext_count"
                fi

                # Count bookmarks
                if [[ -f "$profile/Bookmarks" ]]; then
                    echo "    Has Bookmarks: Yes"
                fi

                echo ""
            done
        else
            echo "Chrome not found or no profiles"
        fi
        echo ""

        # Firefox
        echo "━━━ Firefox ━━━"
        local firefox_dir="${HOME}/Library/Application Support/Firefox/Profiles"
        if [[ -d "$firefox_dir" ]]; then
            echo "Firefox directory: $firefox_dir"
            echo "Size: $(get_dir_size "$firefox_dir")"
            echo "Profiles found:"
            find "$firefox_dir" -maxdepth 1 -type d | tail -n +2 | while read -r profile; do
                local profile_name=$(basename "$profile")
                echo "  - $profile_name ($(get_dir_size "$profile"))"

                # Check for prefs.js
                if [[ -f "$profile/prefs.js" ]]; then
                    echo "    Has prefs.js: Yes"
                fi

                # Check for extensions
                local ext_dir="$profile/extensions"
                if [[ -d "$ext_dir" ]]; then
                    local ext_count
                    ext_count=$(find "$ext_dir" -type f -name "*.xpi" 2>/dev/null | wc -l | tr -d ' ')
                    echo "    Extensions: $ext_count"
                fi

                echo ""
            done
        else
            echo "Firefox not found or no profiles"
        fi
        echo ""

        # Safari
        echo "━━━ Safari ━━━"
        local safari_dir="${HOME}/Library/Safari"
        if [[ -d "$safari_dir" ]]; then
            echo "Safari directory: $safari_dir"
            echo "Size: $(get_dir_size "$safari_dir")"

            if [[ -f "$safari_dir/Bookmarks.plist" ]]; then
                echo "Bookmarks: Yes"
            fi

            if [[ -f "$safari_dir/History.db" ]]; then
                echo "History: Yes ($(get_dir_size "$safari_dir/History.db"))"
            fi

            local extensions_dir="${HOME}/Library/Safari/Extensions"
            if [[ -d "$extensions_dir" ]]; then
                local ext_count
                ext_count=$(find "$extensions_dir" -type d -name "*.safariextension" 2>/dev/null | wc -l | tr -d ' ')
                echo "Extensions: $ext_count"
            fi
        else
            echo "Safari data not found"
        fi
        echo ""

        echo "═══════════════════════════════════════════════════════════"
        echo "BACKUP RECOMMENDATION:"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        if [[ -d "$chrome_dir" ]]; then
            echo "To backup Chrome profiles:"
            echo "  rsync -av \"$chrome_dir\" /path/to/backup/"
        fi
        if [[ -d "$firefox_dir" ]]; then
            echo "To backup Firefox profiles:"
            echo "  rsync -av \"$firefox_dir\" /path/to/backup/"
        fi
        if [[ -d "$safari_dir" ]]; then
            echo "To backup Safari data:"
            echo "  rsync -av \"$safari_dir\" /path/to/backup/"
        fi

    } > "$output"

    print_info "Browser profiles saved to: $output"
}

#############################################################################
# DOTFILES AND CONFIGURATION
#############################################################################

assess_dotfiles() {
    print_section "DOTFILES AND CONFIGURATION"
    local output="${REPORT_DIR}/07_dotfiles.txt"

    print_info "Scanning for dotfiles in home directory..."

    {
        echo "=== Dotfiles in Home Directory ==="
        echo ""

        # Common dotfiles to check
        local important_dotfiles=(
            ".zshrc"
            ".bashrc"
            ".bash_profile"
            ".profile"
            ".vimrc"
            ".gitconfig"
            ".gitignore_global"
            ".ssh/config"
            ".ssh/known_hosts"
            ".ssh/id_rsa"
            ".ssh/id_ed25519"
            ".config"
            ".aws"
            ".docker"
            ".kube/config"
            ".gnupg"
            ".mackup.cfg"
            ".mackup"
        )

        echo "━━━ Important Dotfiles ━━━"
        for dotfile in "${important_dotfiles[@]}"; do
            local full_path="${HOME}/${dotfile}"
            if [[ -e "$full_path" ]]; then
                if [[ -f "$full_path" ]]; then
                    echo "✓ $dotfile (file, $(get_dir_size "$full_path"))"
                elif [[ -d "$full_path" ]]; then
                    local file_count
                    file_count=$(count_files "$full_path")
                    echo "✓ $dotfile (directory, $(get_dir_size "$full_path"), $file_count files)"
                fi
            fi
        done
        echo ""

        echo "━━━ All Dotfiles (.) in Home ━━━"
        find "${HOME}" -maxdepth 1 -name ".*" ! -name "." ! -name ".." -exec basename {} \; | sort
        echo ""
        echo "Total: $(find "${HOME}" -maxdepth 1 -name ".*" ! -name "." ! -name ".." | wc -l | tr -d ' ')"
        echo ""

        echo "━━━ SSH Keys ━━━"
        if [[ -d "${HOME}/.ssh" ]]; then
            echo "SSH directory: ${HOME}/.ssh"
            ls -lh "${HOME}/.ssh"
            echo ""

            # Check for private keys
            echo "⚠️  IMPORTANT: Private SSH keys found:"
            find "${HOME}/.ssh" -type f ! -name "*.pub" ! -name "known_hosts" ! -name "config" ! -name "authorized_keys" 2>/dev/null || echo "None"
            echo ""
        fi

        echo "━━━ GPG Keys ━━━"
        if [[ -d "${HOME}/.gnupg" ]]; then
            echo "GnuPG directory: ${HOME}/.gnupg"
            echo "Size: $(get_dir_size "${HOME}/.gnupg")"

            if command_exists gpg; then
                echo ""
                echo "GPG keys:"
                gpg --list-secret-keys 2>/dev/null || echo "No keys found"
            fi
        fi
        echo ""

        echo "━━━ Git Configuration ━━━"
        if [[ -f "${HOME}/.gitconfig" ]]; then
            echo "Git config found at: ${HOME}/.gitconfig"
            echo ""
            echo "User config:"
            git config --global user.name 2>/dev/null || echo "Not set"
            git config --global user.email 2>/dev/null || echo "Not set"
            echo ""
        fi

    } > "$output"

    print_info "Dotfiles assessment saved to: $output"
}

#############################################################################
# SENSITIVE FILES AND CREDENTIALS
#############################################################################

assess_sensitive_files() {
    print_section "SENSITIVE FILES AND CREDENTIALS"
    local output="${REPORT_DIR}/08_sensitive_files.txt"

    print_info "Scanning for sensitive files (this may take a while)..."

    {
        echo "=== Sensitive Files and Credentials ==="
        echo ""
        echo "⚠️  These files may contain sensitive information"
        echo "   Ensure they are properly backed up and encrypted"
        echo ""

        # Search patterns for sensitive files
        local patterns=(
            "*.env"
            "*.pem"
            "*.key"
            "*.p12"
            "*.pfx"
            "*credentials*"
            "*secrets*"
            "*.keychain"
        )

        # Directories to search
        local search_dirs=(
            "${HOME}/Documents"
            "${HOME}/Desktop"
            "${HOME}/.aws"
            "${HOME}/.ssh"
            "${HOME}/.gnupg"
            "${HOME}/.config"
        )

        for base_dir in "${search_dirs[@]}"; do
            if [[ ! -d "$base_dir" ]]; then
                continue
            fi

            echo "━━━ Searching in: $base_dir ━━━"

            for pattern in "${patterns[@]}"; do
                local found_files
                found_files=$(find "$base_dir" -type f -name "$pattern" 2>/dev/null | head -20)

                if [[ -n "$found_files" ]]; then
                    echo ""
                    echo "Pattern: $pattern"
                    echo "$found_files" | while read -r file; do
                        echo "  ⚠️  $file ($(get_dir_size "$file"))"
                    done
                fi
            done
            echo ""
        done

        echo "━━━ Keychains ━━━"
        local keychain_dir="${HOME}/Library/Keychains"
        if [[ -d "$keychain_dir" ]]; then
            echo "Keychain directory: $keychain_dir"
            echo "Size: $(get_dir_size "$keychain_dir")"
            ls -lh "$keychain_dir" 2>/dev/null | grep -v "^total" || true
        fi
        echo ""

        echo "═══════════════════════════════════════════════════════════"
        echo "⚠️  CRITICAL BACKUP REMINDER:"
        echo "═══════════════════════════════════════════════════════════"
        echo "1. SSH keys: Back up ~/.ssh/ (especially private keys)"
        echo "2. GPG keys: Export with 'gpg --export-secret-keys'"
        echo "3. Keychains: Back up ~/Library/Keychains/"
        echo "4. .env files: Ensure all environment variables are documented"
        echo "5. API keys and credentials: Document all services used"

    } > "$output"

    print_info "Sensitive files assessment saved to: $output"
}

#############################################################################
# SYSTEM PREFERENCES AND DEFAULTS
#############################################################################

assess_system_preferences() {
    print_section "SYSTEM PREFERENCES"
    local output="${REPORT_DIR}/09_system_preferences.txt"

    print_info "Exporting system preferences..."

    {
        echo "=== macOS System Preferences ==="
        echo ""

        echo "━━━ Dock Preferences ━━━"
        defaults read com.apple.dock 2>/dev/null || echo "Could not read Dock preferences"
        echo ""

        echo "━━━ Finder Preferences ━━━"
        defaults read com.apple.finder 2>/dev/null || echo "Could not read Finder preferences"
        echo ""

        echo "━━━ Global Preferences ━━━"
        defaults read NSGlobalDomain 2>/dev/null | head -100 || echo "Could not read global preferences"
        echo ""

        echo "━━━ Trackpad Preferences ━━━"
        defaults read com.apple.AppleMultitouchTrackpad 2>/dev/null || echo "Could not read trackpad preferences"
        echo ""

        echo "━━━ Keyboard Preferences ━━━"
        defaults read com.apple.HIToolbox 2>/dev/null || echo "Could not read keyboard preferences"
        echo ""

    } > "$output"

    # Create a script to restore preferences
    local restore_script="${REPORT_DIR}/restore_system_preferences.sh"
    {
        echo "#!/bin/bash"
        echo "# Script to restore system preferences"
        echo "# Generated on $(date)"
        echo ""
        echo "# NOTE: Review these commands before running!"
        echo ""
        echo "# Dock settings"
        echo "# defaults write com.apple.dock <key> <value>"
        echo ""
        echo "# Finder settings"
        echo "# defaults write com.apple.finder <key> <value>"
        echo ""
        echo "# Restart affected services"
        echo "# killall Dock"
        echo "# killall Finder"
    } > "$restore_script"
    chmod +x "$restore_script"

    print_info "System preferences saved to: $output"
}

#############################################################################
# LARGE FILES AND DIRECTORIES
#############################################################################

assess_large_files() {
    print_section "LARGE FILES AND DIRECTORIES"
    local output="${REPORT_DIR}/10_large_files.txt"

    print_info "Finding large files (>100MB) - this may take several minutes..."

    {
        echo "=== Large Files and Directories ==="
        echo ""

        echo "━━━ Top 50 Largest Files (>100MB) ━━━"
        echo ""
        find "${HOME}" -type f -size +100M 2>/dev/null -exec du -h {} \; | sort -rh | head -50 || echo "No large files found"
        echo ""

        echo "━━━ Top 20 Largest Directories ━━━"
        echo ""
        du -h "${HOME}" 2>/dev/null | sort -rh | head -20 || echo "Could not calculate directory sizes"
        echo ""

        echo "━━━ Downloads Folder ━━━"
        if [[ -d "${HOME}/Downloads" ]]; then
            echo "Size: $(get_dir_size "${HOME}/Downloads")"
            echo "Files: $(count_files "${HOME}/Downloads")"
            echo ""
            echo "Largest files in Downloads:"
            find "${HOME}/Downloads" -type f -exec du -h {} \; 2>/dev/null | sort -rh | head -20 || true
        fi
        echo ""

        echo "━━━ Documents Folder ━━━"
        if [[ -d "${HOME}/Documents" ]]; then
            echo "Size: $(get_dir_size "${HOME}/Documents")"
            echo "Files: $(count_files "${HOME}/Documents")"
        fi
        echo ""

        echo "━━━ Desktop Folder ━━━"
        if [[ -d "${HOME}/Desktop" ]]; then
            echo "Size: $(get_dir_size "${HOME}/Desktop")"
            echo "Files: $(count_files "${HOME}/Desktop")"
        fi

    } > "$output"

    print_info "Large files assessment saved to: $output"
}

#############################################################################
# DEVELOPMENT ENVIRONMENTS
#############################################################################

assess_dev_environments() {
    print_section "DEVELOPMENT ENVIRONMENTS"
    local output="${REPORT_DIR}/11_dev_environments.txt"

    print_info "Checking installed development tools..."

    {
        echo "=== Development Environments ==="
        echo ""

        # Programming languages and runtimes
        echo "━━━ Programming Languages ━━━"
        echo ""

        if command_exists python3; then
            echo "Python 3: $(python3 --version 2>&1)"
            echo "  Location: $(which python3)"
        fi

        if command_exists python; then
            echo "Python: $(python --version 2>&1)"
            echo "  Location: $(which python)"
        fi

        if command_exists node; then
            echo "Node.js: $(node --version)"
            echo "  Location: $(which node)"
            echo "  npm: $(npm --version)"
        fi

        if command_exists ruby; then
            echo "Ruby: $(ruby --version)"
            echo "  Location: $(which ruby)"
        fi

        if command_exists go; then
            echo "Go: $(go version)"
            echo "  Location: $(which go)"
        fi

        if command_exists java; then
            echo "Java: $(java -version 2>&1 | head -1)"
            echo "  Location: $(which java)"
        fi

        if command_exists rustc; then
            echo "Rust: $(rustc --version)"
            echo "  Location: $(which rustc)"
        fi

        if command_exists php; then
            echo "PHP: $(php --version | head -1)"
            echo "  Location: $(which php)"
        fi

        echo ""
        echo "━━━ Package Managers ━━━"
        echo ""

        if command_exists pip3; then
            echo "pip3: $(pip3 --version)"
        fi

        if command_exists npm; then
            echo "npm: $(npm --version)"
            echo "Global packages:"
            npm list -g --depth=0 2>/dev/null | head -20 || true
        fi

        if command_exists gem; then
            echo "gem: $(gem --version)"
            echo "Installed gems: $(gem list | wc -l | tr -d ' ')"
        fi

        if command_exists cargo; then
            echo "cargo: $(cargo --version)"
        fi

        if command_exists composer; then
            echo "composer: $(composer --version 2>/dev/null | head -1)"
        fi

        echo ""
        echo "━━━ Version Managers ━━━"
        echo ""

        if [[ -d "${HOME}/.nvm" ]]; then
            echo "nvm: Installed at ${HOME}/.nvm"
            if [[ -f "${HOME}/.nvm/nvm.sh" ]]; then
                source "${HOME}/.nvm/nvm.sh"
                echo "  Current version: $(nvm current 2>/dev/null || echo 'none')"
                echo "  Installed versions:"
                nvm list 2>/dev/null || true
            fi
        fi

        if [[ -d "${HOME}/.rvm" ]]; then
            echo "rvm: Installed at ${HOME}/.rvm"
        fi

        if [[ -d "${HOME}/.rbenv" ]]; then
            echo "rbenv: Installed at ${HOME}/.rbenv"
            if command_exists rbenv; then
                echo "  Current version: $(rbenv version 2>/dev/null || echo 'none')"
            fi
        fi

        if [[ -d "${HOME}/.pyenv" ]]; then
            echo "pyenv: Installed at ${HOME}/.pyenv"
            if command_exists pyenv; then
                echo "  Current version: $(pyenv version 2>/dev/null || echo 'none')"
            fi
        fi

        echo ""
        echo "━━━ Databases ━━━"
        echo ""

        if command_exists psql; then
            echo "PostgreSQL: $(psql --version)"
        fi

        if command_exists mysql; then
            echo "MySQL: $(mysql --version)"
        fi

        if command_exists mongo; then
            echo "MongoDB: $(mongo --version 2>&1 | head -1)"
        fi

        if command_exists redis-cli; then
            echo "Redis: $(redis-cli --version)"
        fi

        echo ""
        echo "━━━ Containerization ━━━"
        echo ""

        if command_exists docker; then
            echo "Docker: $(docker --version)"
            echo "  Images: $(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | wc -l | tr -d ' ')"
            echo "  Containers: $(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')"
        fi

        if command_exists docker-compose; then
            echo "Docker Compose: $(docker-compose --version)"
        fi

        if command_exists vagrant; then
            echo "Vagrant: $(vagrant --version)"
        fi

        echo ""
        echo "━━━ Virtual Environments ━━━"
        echo ""

        # Python virtual environments
        echo "Python virtual environments in common locations:"
        find "${HOME}" -maxdepth 3 -type d -name "venv" -o -name ".venv" -o -name "env" 2>/dev/null | head -20 || echo "None found"

    } > "$output"

    print_info "Development environments saved to: $output"
}

#############################################################################
# FOLDER OVERLAP ANALYSIS
#############################################################################

assess_app_development() {
    print_section "APP DEVELOPMENT SPECIFIC DATA"
    local output="${REPORT_DIR}/12_app_development.txt"

    print_info "Scanning app development environments and data..."

    {
        echo "=== App Development Specific Data ==="
        echo ""

        # Xcode
        echo "━━━ Xcode ━━━"
        if command_exists xcodebuild; then
            echo "Xcode version: $(xcodebuild -version 2>/dev/null | head -1)"
            echo ""

            # Xcode Preferences
            local xcode_prefs="${HOME}/Library/Preferences/com.apple.dt.Xcode.plist"
            if [[ -f "$xcode_prefs" ]]; then
                echo "✓ Xcode preferences: $xcode_prefs"
            fi

            # Xcode User Data
            local xcode_userdata="${HOME}/Library/Developer/Xcode/UserData"
            if [[ -d "$xcode_userdata" ]]; then
                echo "✓ Xcode UserData: $xcode_userdata"
                echo "  Size: $(get_dir_size "$xcode_userdata")"
                echo "  Contents:"
                echo "    - Code Snippets: $(count_files "$xcode_userdata/CodeSnippets")"
                echo "    - Key Bindings: $(find "$xcode_userdata" -name "*.idekeybindings" 2>/dev/null | wc -l | tr -d ' ')"
                echo "    - Font & Color Themes: $(find "$xcode_userdata" -name "*.xccolortheme" 2>/dev/null | wc -l | tr -d ' ')"
            fi

            # Derived Data
            local derived_data="${HOME}/Library/Developer/Xcode/DerivedData"
            if [[ -d "$derived_data" ]]; then
                echo "⚠️  DerivedData: $derived_data"
                echo "  Size: $(get_dir_size "$derived_data")"
                echo "  (Usually safe to delete, but may contain large caches)"
            fi

            # Archives
            local archives="${HOME}/Library/Developer/Xcode/Archives"
            if [[ -d "$archives" ]]; then
                echo "✓ Xcode Archives: $archives"
                echo "  Size: $(get_dir_size "$archives")"
                echo "  Count: $(find "$archives" -name "*.xcarchive" 2>/dev/null | wc -l | tr -d ' ')"
            fi
        else
            echo "Xcode not installed"
        fi
        echo ""

        # Apple Developer Certificates & Provisioning Profiles
        echo "━━━ Apple Developer Certificates & Provisioning Profiles ━━━"

        local provisioning_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
        if [[ -d "$provisioning_dir" ]]; then
            local profile_count
            profile_count=$(find "$provisioning_dir" -name "*.mobileprovision" 2>/dev/null | wc -l | tr -d ' ')
            echo "✓ Provisioning Profiles: $profile_count found"
            echo "  Location: $provisioning_dir"
            echo ""

            if [[ $profile_count -gt 0 ]]; then
                echo "  Profiles:"
                find "$provisioning_dir" -name "*.mobileprovision" -exec basename {} \; 2>/dev/null | head -20
            fi
        else
            echo "No provisioning profiles found"
        fi
        echo ""

        # Check certificates in keychain
        if command_exists security; then
            echo "Developer Certificates in Keychain:"
            security find-identity -v -p codesigning 2>/dev/null | grep -i "Developer" || echo "  No developer certificates found"
        fi
        echo ""

        # VS Code
        echo "━━━ Visual Studio Code ━━━"
        local vscode_settings="${HOME}/Library/Application Support/Code/User"
        if [[ -d "$vscode_settings" ]]; then
            echo "✓ VS Code settings directory: $vscode_settings"
            echo "  Size: $(get_dir_size "$vscode_settings")"

            if [[ -f "$vscode_settings/settings.json" ]]; then
                echo "  ✓ settings.json exists"
            fi

            if [[ -f "$vscode_settings/keybindings.json" ]]; then
                echo "  ✓ keybindings.json exists"
            fi

            if [[ -f "$vscode_settings/snippets" ]]; then
                echo "  ✓ Custom snippets exist"
            fi

            # Extensions
            if command_exists code; then
                echo ""
                echo "  Installed extensions:"
                code --list-extensions 2>/dev/null || echo "  Could not list extensions"
                echo ""
                echo "  To export: code --list-extensions > vscode_extensions.txt"
                echo "  To restore: cat vscode_extensions.txt | xargs -n 1 code --install-extension"
            fi
        else
            echo "VS Code not found or not configured"
        fi
        echo ""

        # IntelliJ IDEA / Android Studio / JetBrains IDEs
        echo "━━━ JetBrains IDEs ━━━"
        local jetbrains_base="${HOME}/Library/Application Support/JetBrains"
        local android_studio_base="${HOME}/Library/Application Support/Google/AndroidStudio"

        if [[ -d "$jetbrains_base" ]]; then
            echo "✓ JetBrains IDEs configuration: $jetbrains_base"
            echo "  Size: $(get_dir_size "$jetbrains_base")"
            echo "  IDEs found:"
            find "$jetbrains_base" -maxdepth 1 -type d | tail -n +2 | while read -r ide_dir; do
                echo "    - $(basename "$ide_dir") ($(get_dir_size "$ide_dir"))"
            done
        fi

        if [[ -d "$android_studio_base" ]]; then
            echo ""
            echo "✓ Android Studio configuration: $android_studio_base"
            echo "  Size: $(get_dir_size "$android_studio_base")"
        fi

        if [[ ! -d "$jetbrains_base" && ! -d "$android_studio_base" ]]; then
            echo "No JetBrains IDEs found"
        fi
        echo ""

        # Android SDK
        echo "━━━ Android SDK ━━━"
        local android_home="${ANDROID_HOME:-${HOME}/Library/Android/sdk}"
        if [[ -d "$android_home" ]]; then
            echo "✓ Android SDK: $android_home"
            echo "  Size: $(get_dir_size "$android_home")"

            if [[ -f "$android_home/tools/bin/sdkmanager" ]] || command_exists sdkmanager; then
                echo ""
                echo "  Installed packages:"
                "$android_home/tools/bin/sdkmanager" --list_installed 2>/dev/null | head -30 || sdkmanager --list_installed 2>/dev/null | head -30 || echo "  Could not list packages"
            fi
        else
            echo "Android SDK not found"
        fi
        echo ""

        # iOS Simulators
        echo "━━━ iOS Simulators ━━━"
        local simulators_dir="${HOME}/Library/Developer/CoreSimulator/Devices"
        if [[ -d "$simulators_dir" ]]; then
            echo "✓ Simulator data: $simulators_dir"
            echo "  Size: $(get_dir_size "$simulators_dir")"

            if command_exists xcrun; then
                echo ""
                echo "  Installed simulators:"
                xcrun simctl list devices 2>/dev/null | grep -E "iPhone|iPad|Apple" | head -20 || echo "  Could not list simulators"
            fi
        fi
        echo ""

        # CocoaPods
        echo "━━━ CocoaPods ━━━"
        if command_exists pod; then
            echo "✓ CocoaPods version: $(pod --version 2>/dev/null)"

            local pods_cache="${HOME}/Library/Caches/CocoaPods"
            if [[ -d "$pods_cache" ]]; then
                echo "  Cache: $pods_cache ($(get_dir_size "$pods_cache"))"
            fi
        else
            echo "CocoaPods not installed"
        fi
        echo ""

        # React Native / Expo
        echo "━━━ React Native / Expo ━━━"
        if command_exists react-native; then
            echo "✓ React Native CLI: $(react-native --version 2>/dev/null | head -1)"
        fi

        if command_exists expo; then
            echo "✓ Expo CLI: $(expo --version 2>/dev/null)"
        fi

        if [[ ! $(command_exists react-native) && ! $(command_exists expo) ]]; then
            echo "React Native / Expo not installed"
        fi
        echo ""

        # Flutter
        echo "━━━ Flutter ━━━"
        if command_exists flutter; then
            echo "✓ Flutter: $(flutter --version 2>/dev/null | head -1)"
            echo "  Location: $(which flutter)"
        else
            echo "Flutter not installed"
        fi
        echo ""

        # Fastlane
        echo "━━━ Fastlane ━━━"
        if command_exists fastlane; then
            echo "✓ Fastlane version: $(fastlane --version 2>/dev/null | head -1)"
        else
            echo "Fastlane not installed"
        fi
        echo ""

        # CI/CD Configurations
        echo "━━━ CI/CD Configuration Files ━━━"
        echo "Looking for CI/CD configs in common project directories..."
        local project_dirs=(
            "${HOME}/Documents"
            "${HOME}/Projects"
            "${HOME}/Dev"
            "${HOME}/Development"
        )

        local ci_files=(
            ".github/workflows/*.yml"
            ".gitlab-ci.yml"
            ".travis.yml"
            "circle.yml"
            ".circleci/config.yml"
            "Jenkinsfile"
            "bitbucket-pipelines.yml"
        )

        for base_dir in "${project_dirs[@]}"; do
            if [[ ! -d "$base_dir" ]]; then
                continue
            fi

            for pattern in "${ci_files[@]}"; do
                local found_count
                found_count=$(find "$base_dir" -path "*/${pattern}" 2>/dev/null | wc -l | tr -d ' ')
                if [[ $found_count -gt 0 ]]; then
                    echo "  Found $found_count x $pattern in $base_dir"
                fi
            done
        done
        echo ""

        echo "═══════════════════════════════════════════════════════════"
        echo "APP DEVELOPMENT BACKUP RECOMMENDATIONS:"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "🔴 CRITICAL - Must Backup:"
        echo "  • Apple Developer certificates & provisioning profiles"
        echo "  • Xcode code snippets and key bindings"
        echo "  • VS Code settings, keybindings, and extensions list"
        echo "  • IDE settings and configurations"
        echo "  • Git repositories (all uncommitted work!)"
        echo ""
        echo "🟡 IMPORTANT - Should Backup:"
        echo "  • Xcode archives (for app store submissions)"
        echo "  • Custom Xcode themes and templates"
        echo "  • Database dumps from local development"
        echo "  • .env files with API keys"
        echo "  • CI/CD configuration files"
        echo ""
        echo "🟢 OPTIONAL - Can Rebuild:"
        echo "  • Xcode DerivedData (can be regenerated)"
        echo "  • CocoaPods cache (will re-download)"
        echo "  • Node modules (npm install)"
        echo "  • Simulator data (can recreate)"
        echo ""

    } > "$output"

    print_info "App development data saved to: $output"
}

assess_folder_overlap() {
    print_section "FOLDER OVERLAP ANALYSIS"
    local output="${REPORT_DIR}/13_folder_overlap.txt"

    print_info "Analyzing potential duplicate/overlapping files..."

    {
        echo "=== Folder Overlap and Duplicate Analysis ==="
        echo ""
        echo "Looking for common backup folder patterns..."
        echo ""

        # Common backup folder patterns
        local backup_patterns=(
            "*backup*"
            "*Backup*"
            "*BACKUP*"
            "*old*"
            "*OLD*"
            "*archive*"
            "*Archive*"
            "*copy*"
            "*Copy*"
            "*_bak"
            "*.bak"
        )

        echo "━━━ Backup-like Folders ━━━"
        for pattern in "${backup_patterns[@]}"; do
            find "${HOME}" -maxdepth 3 -type d -name "$pattern" 2>/dev/null | while read -r dir; do
                echo "Found: $dir"
                echo "  Size: $(get_dir_size "$dir")"
                echo "  Files: $(count_files "$dir")"
                echo ""
            done
        done

        echo ""
        echo "━━━ Potential Duplicate Files (by name) ━━━"
        echo ""
        echo "Finding files with 'copy', 'backup', or version numbers in name..."
        find "${HOME}/Documents" "${HOME}/Desktop" -type f \( -name "*copy*" -o -name "*backup*" -o -name "*\ [0-9]*" \) 2>/dev/null | head -50 || echo "None found"
        echo ""

        if command_exists fdupes; then
            echo "━━━ Exact Duplicate Files (using fdupes) ━━━"
            echo ""
            fdupes -r "${HOME}/Documents" 2>/dev/null | head -100 || echo "fdupes not available or no duplicates found"
        else
            echo "━━━ Exact Duplicates ━━━"
            echo "Install 'fdupes' for duplicate detection: brew install fdupes"
        fi

    } > "$output"

    print_info "Folder overlap analysis saved to: $output"
}

#############################################################################
# FINAL SUMMARY
#############################################################################

generate_summary() {
    print_section "GENERATING FINAL SUMMARY"
    local summary="${REPORT_DIR}/00_SUMMARY.txt"

    {
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║                                                               ║"
        echo "║        MAC DATA ASSESSMENT SUMMARY REPORT                     ║"
        echo "║                                                               ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date)"
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        echo "Report Directory: ${REPORT_DIR}"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "REPORT FILES GENERATED"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        ls -lh "${REPORT_DIR}" | grep -v "^total" | grep -v "^d"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "CRITICAL ITEMS TO BACKUP"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "🔴 HIGH PRIORITY:"
        echo "  - Git repositories with uncommitted changes"
        echo "  - SSH keys (~/.ssh/)"
        echo "  - GPG keys (~/.gnupg/)"
        echo "  - Browser profiles (Chrome, Firefox, Safari)"
        echo "  - Environment files (.env, credentials)"
        echo "  - System Keychains (~/Library/Keychains/)"
        echo ""
        echo "🟡 MEDIUM PRIORITY:"
        echo "  - Dotfiles (.zshrc, .gitconfig, etc.)"
        echo "  - Application preferences"
        echo "  - Development environment configs"
        echo "  - Homebrew package lists (Brewfile)"
        echo "  - Mac App Store apps list"
        echo ""
        echo "🟢 LOW PRIORITY:"
        echo "  - Clean git repositories (already pushed)"
        echo "  - System preferences (can be reconfigured)"
        echo "  - Downloaded files (Downloads folder)"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "NEXT STEPS"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "1. Review all report files in: ${REPORT_DIR}"
        echo ""
        echo "2. Address git repositories with uncommitted changes:"
        echo "   See: 02_git_repositories.txt"
        echo ""
        echo "3. Backup sensitive files and credentials:"
        echo "   See: 08_sensitive_files.txt"
        echo ""
        echo "4. Export/backup browser profiles:"
        echo "   See: 06_browser_profiles.txt"
        echo ""
        echo "5. Save Homebrew packages for restoration:"
        echo "   File: ${REPORT_DIR}/Brewfile"
        echo "   Restore with: brew bundle install"
        echo ""
        echo "6. Document system preferences you want to restore:"
        echo "   See: 09_system_preferences.txt"
        echo ""
        echo "7. Check for large files that may need selective backup:"
        echo "   See: 10_large_files.txt"
        echo ""
        echo "8. Review folder overlap for redundant backups:"
        echo "   See: 12_folder_overlap.txt"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "✓ Assessment complete!"
        echo ""
        echo "Share the entire ${REPORT_DIR} directory for analysis."
        echo ""

    } > "$summary"

    print_info "Summary report created: $summary"
}

#############################################################################
# MAIN EXECUTION
#############################################################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           MAC DATA ASSESSMENT TOOL                            ║"
    echo "║           Before Reinstallation                               ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    print_info "Starting comprehensive assessment..."
    print_info "This will perform READ-ONLY operations on your system"
    print_info "Report will be saved to: ${REPORT_DIR}"
    echo ""

    # Run all assessment functions
    assess_system_info
    assess_git_repos
    assess_homebrew
    assess_mac_app_store
    assess_all_applications
    assess_browser_profiles
    assess_dotfiles
    assess_sensitive_files
    assess_system_preferences
    assess_large_files
    assess_dev_environments
    assess_app_development
    assess_folder_overlap

    # Generate final summary
    generate_summary

    echo ""
    print_section "ASSESSMENT COMPLETE"
    echo ""
    print_info "All reports saved to: ${REPORT_DIR}"
    print_info "Start with: ${REPORT_DIR}/00_SUMMARY.txt"
    echo ""
    print_status "${GREEN}" "════════════════════════════════════════════════════════════════"
    print_status "${GREEN}" "Next step: Review the reports and share the directory"
    print_status "${GREEN}" "════════════════════════════════════════════════════════════════"
    echo ""
}

# Run main function
main "$@"
