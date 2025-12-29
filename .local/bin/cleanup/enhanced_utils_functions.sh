#!/bin/bash

# Colors for better readability
GREEN='\e[0;32m'
RED='\e[0;31m'
BLUE='\e[0;34m'
YELLOW='\e[0;33m'
NC='\e[0m'

# Configuration
BRANCH_PREFIX="migratingmacos-$(date +'%Y%m%d-%H%M%S')"
COMPLETED_FOLDER="/Users/sergio/dev_completed"
LOG_FILE="/Users/sergio/cleanup_log_$(date +'%Y%m%d').txt"

# Load environment variables
[ ! -f .env ] || export $(sed 's/#.*//g' .env | xargs)

# Array of common sensitive files to detect
SENSITIVE_FILES=(".env" "config.json" "config.yaml" "secrets.yml" "keys.json" ".env.migrated_from_mac" "vinted_creds.py")

# Array to store previous owners/orgs
PREVIOUS_OWNERS=("BrightSoftwares" "fullbright")
SELECTED_OWNER=""

# Add logging function for operations
log_action() {
    local action=$1
    local target=$2
    local result=$3
    
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $action: $target - $result" >> "$LOG_FILE"
    echo -e "${BLUE}[LOG]${NC} $action: $target - $result"
}

# Detect project type and generate .gitignore
generate_gitignore() {
    local folder=$1
    echo "Detecting project type for '$folder' and generating .gitignore..."
    
    # Create or append to .gitignore
    local gitignore_file="$folder/.gitignore"
    
    # Add standard entries
    echo "# Generated gitignore - $(date)" >> "$gitignore_file"
    echo ".DS_Store" >> "$gitignore_file"
    echo "*.log" >> "$gitignore_file"
    
    # Detect project type and add specific entries
    if [ -f "$folder/package.json" ]; then
        echo -e "${YELLOW}Node.js project detected. Adding specific rules...${NC}"
        echo "# Node.js" >> "$gitignore_file"
        echo "node_modules/" >> "$gitignore_file"
        echo "npm-debug.log" >> "$gitignore_file"
        echo "yarn-error.log" >> "$gitignore_file"
        echo ".env" >> "$gitignore_file"
        echo ".env.local" >> "$gitignore_file"
        echo ".env.development.local" >> "$gitignore_file"
        echo ".env.test.local" >> "$gitignore_file"
        echo ".env.production.local" >> "$gitignore_file"
    fi
    
    if [ -f "$folder/requirements.txt" ] || [ -d "$folder/venv" ] || find "$folder" -name "*.py" -quit; then
        echo -e "${YELLOW}Python project detected. Adding specific rules...${NC}"
        echo "# Python" >> "$gitignore_file"
        echo "__pycache__/" >> "$gitignore_file"
        echo "*.py[cod]" >> "$gitignore_file"
        echo "*$py.class" >> "$gitignore_file"
        echo "venv/" >> "$gitignore_file"
        echo "env/" >> "$gitignore_file"
        echo ".env" >> "$gitignore_file"
        echo "*.so" >> "$gitignore_file"
    fi
    
    if [ -f "$folder/composer.json" ] || find "$folder" -name "*.php" -quit; then
        echo -e "${YELLOW}PHP project detected. Adding specific rules...${NC}"
        echo "# PHP" >> "$gitignore_file"
        echo "vendor/" >> "$gitignore_file"
        echo "composer.phar" >> "$gitignore_file"
        echo ".env" >> "$gitignore_file"
    fi
    
    if [ -f "$folder/Gemfile" ] || find "$folder" -name "*.rb" -quit; then
        echo -e "${YELLOW}Ruby project detected. Adding specific rules...${NC}"
        echo "# Ruby" >> "$gitignore_file"
        echo ".bundle/" >> "$gitignore_file"
        echo "vendor/bundle" >> "$gitignore_file"
        echo ".env" >> "$gitignore_file"
    fi
    
    if [ -f "$folder/pom.xml" ] || [ -f "$folder/build.gradle" ] || find "$folder" -name "*.java" -quit; then
        echo -e "${YELLOW}Java project detected. Adding specific rules...${NC}"
        echo "# Java" >> "$gitignore_file"
        echo "*.class" >> "$gitignore_file"
        echo "*.jar" >> "$gitignore_file"
        echo "target/" >> "$gitignore_file"
        echo "build/" >> "$gitignore_file"
        echo ".gradle/" >> "$gitignore_file"
    fi
    
    log_action "Generated .gitignore" "$folder" "Success"
    return 0
}

# Encrypt sensitive files
encrypt_sensitive_files() {
    local folder=$1
    local encrypted_count=0
    
    echo -e "${BLUE}Checking for sensitive files in ${folder}...${NC}"
    
    # Ensure GPG passphrase is set
    if [ -z "$GPG_PASSPHRASE" ]; then
        echo -e "${RED}Error: GPG_PASSPHRASE not set in environment.${NC}"
        echo -e "${YELLOW}Skipping encryption step.${NC}"
        return 1
    fi
    
    # Check for sensitive files
    for file in "${SENSITIVE_FILES[@]}"; do
        find "$folder" -name "$file" -type f | while read -r sensitive_file; do
            echo -e "${YELLOW}Found sensitive file: ${sensitive_file}${NC}"
            
            # Get relative path for .gitignore
            local rel_path="${sensitive_file#$folder/}"
            
            # Add to .gitignore before encrypting
            echo "$rel_path" >> "$folder/.gitignore"
            
            # Encrypt file
            gpg --symmetric --batch --yes --passphrase "$GPG_PASSPHRASE" "$sensitive_file"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully encrypted: ${sensitive_file}.gpg${NC}"
                encrypted_count=$((encrypted_count + 1))
                log_action "Encrypted sensitive file" "$sensitive_file" "Success"
            else
                echo -e "${RED}Failed to encrypt: ${sensitive_file}${NC}"
                log_action "Encrypted sensitive file" "$sensitive_file" "Failed"
            fi
        done
    done
    
    if [ $encrypted_count -eq 0 ]; then
        echo -e "${BLUE}No sensitive files found to encrypt.${NC}"
    else
        echo -e "${GREEN}Successfully encrypted ${encrypted_count} sensitive files.${NC}"
    fi
    
    return 0
}

# Check if a folder is a Git repository
is_git_repo() {
    local folder=$1
    if [ -d "$folder/.git" ]; then
        return 0
    else
        return 1
    fi
}

# Get remote URL for a Git repository
get_remote_url() {
    local folder=$1
    
    if is_git_repo "$folder"; then
        git -C "$folder" ls-remote --get-url origin
        return 0
    else
        echo ""
        return 1
    fi
}

# Check if repository is owne