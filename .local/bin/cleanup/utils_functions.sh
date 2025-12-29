
BRANCH_PREFIX="migratingmacos-$(date +'%Y%m%d-%H%M%S')"

# Array of common sensitive files to detect
SENSITIVE_FILES=(".env" "config.json" "config.yaml" "secrets.yml" "keys.json" ".env.migrated_from_mac" "vinted_creds.py")


# Function to detect project type and generate .gitignore
generate_gitignore() {
    local folder=$1
    echo "Detecting project type for '$folder' and generating .gitignore..."
    if [ -f "$folder/package.json" ]; then
        echo "node_modules/" >> "$folder/.gitignore"
        echo "Node.js project detected. Adding 'node_modules/' to .gitignore."
    elif [ -f "$folder/requirements.txt" ]; then
        echo "__pycache__/" >> "$folder/.gitignore"
        echo "Python project detected. Adding '__pycache__/' to .gitignore."
    elif [ -f "$folder/composer.json" ]; then
        echo "vendor/" >> "$folder/.gitignore"
        echo "PHP project detected. Adding 'vendor/' to .gitignore."
    else
        echo "# General .gitignore template" >> "$folder/.gitignore"
        echo ".DS_Store" >> "$folder/.gitignore"
        echo "Project type undetermined. Adding a general .gitignore template."
    fi
}

# Function to encrypt sensitive files
encrypt_sensitive_files() {
    local folder=$1
    for file in "${SENSITIVE_FILES[@]}"; do
        if [ -f "$folder/$file" ]; then
            echo "Encrypting sensitive file '$file' in folder '$folder'..."
            gpg --symmetric --batch --passphrase "$GPG_PASSPHRASE" "$folder/$file"
            echo "$file" >> "$folder/.gitignore"  # Add unencrypted file to .gitignore
            echo "Added '$file' to .gitignore to exclude unencrypted version."
        fi
    done
}

# Function to check if a folder is a Git repository
is_git_repo() {
    local folder=$1
    [ -d "$folder/.git" ]
}

# Function to prompt for GitHub owner/org from a list of previous values
choose_owner() {
    echo "Selecting GitHub owner/org for this repository..."
    if [ ${#PREVIOUS_OWNERS[@]} -gt 0 ]; then
        echo "Choose from the previous owners/orgs below:"
        for i in "${!PREVIOUS_OWNERS[@]}"; do
            echo "$((i+1))) ${PREVIOUS_OWNERS[i]}"
        done
        echo "$(( ${#PREVIOUS_OWNERS[@]} + 1 ))) Enter a new owner/org"
    else
        echo "No previous owners/orgs available. Please enter a new owner/org."
    fi

    read -r selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection > 0 && selection <= ${#PREVIOUS_OWNERS[@]} )); then
        owner=${PREVIOUS_OWNERS[$((selection - 1))]}
        echo "Selected existing owner/org: $owner"
    else
        echo "Enter the GitHub owner/org name:"
        read -r owner
        if [[ ! " ${PREVIOUS_OWNERS[@]} " =~ " $owner " ]]; then
            PREVIOUS_OWNERS+=("$owner")
            echo "Added '$owner' to the list of previous owners/orgs."
        fi
    fi
    SELECTED_OWNER=$owner
    echo "$owner"
}

# Function to create a GitHub repository and link it
create_github_repo() {
    local repo_name=$1
    local owner=$2
    echo "Creating new GitHub repository '$owner/$repo_name'..."
    gh repo create "$owner/$repo_name" --public --source="$folder" --remote=origin --confirm
    echo "Repository '$owner/$repo_name' created and linked."
}

# Function to open file explorer for user navigation
explore_folder() {
    local folder=$1
    echo "Opening file explorer for '$folder'. Please review the contents..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "$folder"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "$folder"
    elif [[ "$OSTYPE" == "win32" ]]; then
        explorer "$folder"
    fi
}