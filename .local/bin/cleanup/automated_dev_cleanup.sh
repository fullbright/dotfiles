#!/bin/bash

source utils_functions.sh

# Define constants for GPG passphrase and branch name format
[ ! -f .env ] || export $(sed 's/#.*//g' .env | xargs)
BRANCH_PREFIX="migratingmacos-$(date +'%Y%m%d-%H%M%S')"

# Array of common sensitive files to detect
SENSITIVE_FILES=(".env" "config.json" "config.yaml" "secrets.yml" "keys.json")

# Array to store previous owners/orgs
PREVIOUS_OWNERS=("BrightSoftwares" "fullbright")
SELECTED_OWNER=""
COMPLETED_FOLDER="/Users/sergio/dev_completed"


# Main workflow function for processing each folder
process_folder() {
    local tmp_folder=$1
    local repo_name=$(basename "$tmp_folder")

    echo "Processing folder '$tmp_folder'..."

    # Step 1: Check if folder is a Git repository
    if is_git_repo "$tmp_folder"; then
        echo "Folder '$tmp_folder' is already a Git repository."
        git -C "$tmp_folder" remote show origin

        # Prompt user for owner/org selection
        local owner
        #owner=$(choose_owner)
        choose_owner
        owner=$SELECTED_OWNER
        local full_repo_name="$owner/$repo_name"
        echo "https://github.com/$owner/$repo_name"

        # Check if it belongs to the user, or fork if not
        if gh repo view "$full_repo_name" &>/dev/null; then
            echo "Repository '$full_repo_name' exists in your GitHub account. Creating new branch '$BRANCH_PREFIX'..."
            git -C "$tmp_folder" checkout -b "$BRANCH_PREFIX"
        else
            echo "Repository '$full_repo_name' does not belong to you. Forking repository..."
            gh repo fork "$full_repo_name" --clone=false
            git -C "$tmp_folder" remote add fork "https://github.com/$owner/$repo_name"
            git -C "$tmp_folder" checkout -b "$BRANCH_PREFIX"
        fi
    else
        echo "Folder '$tmp_folder' is not a Git repository. Do you want to keep this code? (y/n)"

        # Open file explorer to navigate contents
        explore_folder "$tmp_folder"

        read -r keep
        if [ "$keep" != "y" ]; then
            echo "Skipping folder '$tmp_folder'."
            return
        fi

        # Check for similar repositories in user account
        echo "Checking for similar repositories in your account..."
        local owner
        #owner=$(choose_owner)
        choose_owner
        owner=$SELECTED_OWNER
        local full_repo_name="$owner/$repo_name"
        
        gh repo list "$owner" --limit 100 | grep -i "$repo_name"
        if [ $? -eq 0 ]; then
            echo "A similar repository named '$repo_name' was found. Link to this repository? (y/n)"
            read -r link_existing
            if [ "$link_existing" == "y" ]; then
                echo "Cloning existing repository '$full_repo_name' to '$tmp_folder'..."
                gh repo clone "$full_repo_name" "$tmp_folder"
            else
                create_github_repo "$repo_name" "$owner"
            fi
        else
            create_github_repo "$repo_name" "$owner"
        fi
    fi

    # Step 2: Generate .gitignore and encrypt sensitive files
    generate_gitignore "$tmp_folder"
    encrypt_sensitive_files "$tmp_folder"

    # Step 3: Commit and push changes
    echo "Committing changes in '$tmp_folder' and pushing to branch '$BRANCH_PREFIX'..."
    cd "$tmp_folder" || exit
    git add .
    git commit -m "Automated migration commit"
    git push origin "$BRANCH_PREFIX"
    echo "Changes pushed to branch '$BRANCH_PREFIX' in '$full_repo_name'."

    # Step 4: Clean up local folder after successful push
    cd ..
    #rm -rf "$tmp_folder"
    echo "moving $tmp_folder to $COMPLETED_FOLDER"
    mv "$tmp_folder" "$COMPLETED_FOLDER"
    echo "Deleted local folder '$tmp_folder' after successful migration."
}

# Loop over each folder in the target directory
TARGET_DIR="$1"
# echo "Starting migration for all folders in '$TARGET_DIR'..."
# for curr_folder in "$TARGET_DIR"/*; do
#     echo ""
#     echo ">>> Processing folder $curr_folder"
#     if [ -d "$curr_folder" ]; then
#         process_folder "$curr_folder"
#     else
#         echo "Skipping '$curr_folder' as it is not a directory."
#     fi
# done

# # Use find to get only directories in TARGET_DIR
# find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r folder; do
#     echo "Checking '$folder'..."
#     if [ -d "$folder" ]; then
#         process_folder "$folder"
#     else
#         echo "Skipping '$folder' as it is not a directory."
#     fi
# done

# Use find to get only directories in TARGET_DIR and avoid additional -d check
find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r folder; do
    echo "Found directory: '$folder'"

    # Process folder directly without additional checks
    process_folder "$folder"
done


# echo "calling choose owner"
# #owner=$(choose_owner)
# choose_owner
# echo "selected owner $SELECTED_OWNER"

# echo "choose owner again"
# #owner=$(choose_owner)
# choose_owner
# echo "selected owner $SELECTED_OWNER"

# echo "choose owner a 3rd time"
# #owner=$(choose_owner)
# choose_owner
# echo "selected owner $SELECTED_OWNER"

echo "Migration process completed."
