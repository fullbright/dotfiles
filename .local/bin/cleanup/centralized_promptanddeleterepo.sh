#!/bin/bash

# Colors for better readability
GREEN='\e[0;32m'
RED='\e[0;31m'
BLUE='\e[0;34m'
YELLOW='\e[0;33m'
NC='\e[0m'

source utils_functions.sh

# Base directories
DEV_DIR="/Users/sergio/dev"
COMPLETED_DIR="/Users/sergio/dev_completed"
STATS_DIR="/Users/sergio/cleanup_stats"

# Create necessary directories
mkdir -p "$COMPLETED_DIR"
mkdir -p "$STATS_DIR"

# Main menu function
show_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}     MAC & GITHUB CLEANUP WIZARD      ${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo
    echo -e "${YELLOW}1.${NC} Analyze dev folder (collect requirements)"
    echo -e "${YELLOW}2.${NC} Process repositories not initialized"
    echo -e "${YELLOW}3.${NC} Process external repositories to fork"
    echo -e "${YELLOW}4.${NC} Save pending changes in my repositories"
    echo -e "${YELLOW}5.${NC} Clean up repositories with everything up-to-date"
    echo -e "${YELLOW}6.${NC} Process a specific folder"
    echo -e "${YELLOW}7.${NC} Cleanup Downloads folder"
    echo -e "${YELLOW}8.${NC} Show statistics"
    echo -e "${YELLOW}0.${NC} Exit"
    echo
    echo -e "${BLUE}=======================================${NC}"
    echo -n "Enter your choice [0-8]: "
}

# Function to handle analysis of dev folder
analyze_dev_folder() {
    echo -e "${GREEN}Analyzing dev folder...${NC}"
    bash collect_requirements.sh "$DEV_DIR"
    
    # Show quick stats after analysis
    echo -e "\n${BLUE}Analysis Results:${NC}"
    echo -e "Folders not initialized as Git repos: $(grep -c . stats_local_folder_not_a_repo.txt)"
    echo -e "External repos to fork: $(grep -c . stats_external_repo_to_fork.txt)"
    echo -e "My repos with changes to save: $(grep -c . stats_myrepo_changes_to_save.txt)"
    echo -e "Repos up-to-date: $(grep -c . stats_myrepo_everything_uptodate.txt)"
    
    echo -e "\n${GREEN}Analysis completed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to process uninitialized repositories
process_uninit_repos() {
    echo -e "${GREEN}Processing uninitialized repositories...${NC}"
    
    # Check if file exists and is not empty
    if [ ! -s stats_local_folder_not_a_repo.txt ]; then
        echo -e "${RED}No uninitialized repositories found.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}The following folders need to be initialized:${NC}"
    cat stats_local_folder_not_a_repo.txt
    
    echo -e "\n${BLUE}How would you like to proceed?${NC}"
    echo -e "1. Process all folders automatically"
    echo -e "2. Process folders one by one"
    echo -e "3. Return to main menu"
    read -p "Enter your choice [1-3]: " choice
    
    case $choice in
        1)
            batch_process_uninit_repos
            ;;
        2)
            interactive_process_uninit_repos
            ;;
        *)
            return
            ;;
    esac
}

# Function to batch process uninitialized repositories
batch_process_uninit_repos() {
    local owner
    choose_owner
    owner=$SELECTED_OWNER
    
    echo -e "${YELLOW}All repositories will be created under the organization/user: ${owner}${NC}"
    read -p "Are you sure you want to continue? (y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        return
    fi
    
    while IFS= read -r folder; do
        if [ -z "$folder" ] || [ ! -d "$folder" ]; then
            continue
        fi
        
        repo_name=$(basename "$folder")
        echo -e "\n${GREEN}Processing folder: ${folder}${NC}"
        
        # Create GitHub repo and version the folder
        create_github_repo "$repo_name" "$owner"
        bash version_this_folder.sh "$folder" "https://github.com/${owner}/${repo_name}.git"
        
        # Move to completed folder
        echo -e "Moving ${folder} to ${COMPLETED_DIR}"
        mv "$folder" "$COMPLETED_DIR"
    done < stats_local_folder_not_a_repo.txt
    
    echo -e "\n${GREEN}All uninitialized repositories have been processed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to interactively process uninitialized repositories
interactive_process_uninit_repos() {
    while IFS= read -r folder; do
        if [ -z "$folder" ] || [ ! -d "$folder" ]; then
            continue
        fi
        
        repo_name=$(basename "$folder")
        echo -e "\n${GREEN}Processing folder: ${folder}${NC}"
        
        # Open folder for inspection
        explore_folder "$folder"
        
        echo -e "${YELLOW}Options for ${repo_name}:${NC}"
        echo "1. Create GitHub repo and version"
        echo "2. Skip this folder"
        echo "3. Delete this folder"
        echo "4. Exit to main menu"
        read -p "Enter your choice [1-4]: " choice
        
        case $choice in
            1)
                local owner
                choose_owner
                owner=$SELECTED_OWNER
                
                create_github_repo "$repo_name" "$owner"
                bash version_this_folder.sh "$folder" "https://github.com/${owner}/${repo_name}.git"
                
                # Move to completed folder
                echo -e "Moving ${folder} to ${COMPLETED_DIR}"
                mv "$folder" "$COMPLETED_DIR"
                ;;
            2)
                echo "Skipping folder..."
                ;;
            3)
                echo "Deleting folder..."
                rm -rf "$folder"
                ;;
            4)
                return
                ;;
        esac
    done < stats_local_folder_not_a_repo.txt
    
    echo -e "\n${GREEN}All uninitialized repositories have been processed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to process external repositories to fork
process_external_repos() {
    echo -e "${GREEN}Processing external repositories to fork...${NC}"
    
    # Check if file exists and is not empty
    if [ ! -s stats_external_repo_to_fork.txt ]; then
        echo -e "${RED}No external repositories found.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}The following external repositories need to be forked:${NC}"
    cat stats_external_repo_to_fork.txt
    
    echo -e "\n${BLUE}How would you like to proceed?${NC}"
    echo -e "1. Process all repos automatically"
    echo -e "2. Process repos one by one"
    echo -e "3. Return to main menu"
    read -p "Enter your choice [1-3]: " choice
    
    case $choice in
        1)
            local owner
            choose_owner
            owner=$SELECTED_OWNER
            
            while IFS= read -r folder; do
                if [ -z "$folder" ] || [ ! -d "$folder" ]; then
                    continue
                fi
                
                echo -e "\n${GREEN}Processing folder: ${folder}${NC}"
                bash fork_existing_repo.sh "$owner" "$folder"
                
                # Move to completed folder
                echo -e "Moving ${folder} to ${COMPLETED_DIR}"
                mv "$folder" "$COMPLETED_DIR"
            done < stats_external_repo_to_fork.txt
            ;;
        2)
            while IFS= read -r folder; do
                if [ -z "$folder" ] || [ ! -d "$folder" ]; then
                    continue
                fi
                
                echo -e "\n${GREEN}Processing folder: ${folder}${NC}"
                
                local owner
                choose_owner
                owner=$SELECTED_OWNER
                
                bash fork_existing_repo.sh "$owner" "$folder"
                
                # Ask if we should move to completed folder
                read -p "Move this folder to completed directory? (y/n): " move
                if [ "$move" == "y" ]; then
                    echo -e "Moving ${folder} to ${COMPLETED_DIR}"
                    mv "$folder" "$COMPLETED_DIR"
                fi
            done < stats_external_repo_to_fork.txt
            ;;
        *)
            return
            ;;
    esac
    
    echo -e "\n${GREEN}All external repositories have been processed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to save pending changes in my repositories
save_pending_changes() {
    echo -e "${GREEN}Saving pending changes in my repositories...${NC}"
    
    # Check if file exists and is not empty
    if [ ! -s stats_myrepo_changes_to_save.txt ]; then
        echo -e "${RED}No repositories with pending changes found.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}The following repositories have pending changes:${NC}"
    cat stats_myrepo_changes_to_save.txt
    
    echo -e "\n${BLUE}How would you like to proceed?${NC}"
    echo -e "1. Save all changes"
    echo -e "2. Review repositories one by one"
    echo -e "3. Return to main menu"
    read -p "Enter your choice [1-3]: " choice
    
    case $choice in
        1)
            bash save_pending_changes.sh
            ;;
        2)
            while IFS= read -r folder; do
                if [ -z "$folder" ] || [ ! -d "$folder" ]; then
                    continue
                fi
                
                echo -e "\n${GREEN}Repository: ${folder}${NC}"
                cd "$folder" || continue
                
                echo "Pending changes:"
                git status --short
                
                echo -e "\n${YELLOW}Options:${NC}"
                echo "1. Save changes"
                echo "2. Skip repository"
                echo "3. Return to main menu"
                read -p "Enter your choice [1-3]: " repo_choice
                
                case $repo_choice in
                    1)
                        if test -f ".env"; then
                            echo "Copying the .env file"
                            cp .env .env.migrated_from_mac
                        fi
                        
                        generate_gitignore "$folder"
                        encrypt_sensitive_files "$folder"
                        
                        git switch -c "migration_from_my_mac-$(date +'%Y%m%d-%H%M%S')"
                        git add .
                        git commit -m 'data migrated from my mac'
                        git push --set-upstream origin "migration_from_my_mac-$(date +'%Y%m%d-%H%M%S')"
                        ;;
                    2)
                        echo "Skipping repository..."
                        ;;
                    3)
                        cd - > /dev/null
                        return
                        ;;
                esac
                
                cd - > /dev/null
            done < stats_myrepo_changes_to_save.txt
            ;;
        *)
            return
            ;;
    esac
    
    echo -e "\n${GREEN}All pending changes have been saved.${NC}"
    read -p "Press Enter to continue..."
}

# Function to clean up repositories with everything up-to-date
cleanup_uptodate_repos() {
    echo -e "${GREEN}Cleaning up repositories with everything up-to-date...${NC}"
    
    # Check if file exists and is not empty
    if [ ! -s stats_myrepo_everything_uptodate.txt ]; then
        echo -e "${RED}No up-to-date repositories found.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}The following repositories are up-to-date:${NC}"
    cat stats_myrepo_everything_uptodate.txt
    
    echo -e "\n${BLUE}How would you like to proceed?${NC}"
    echo -e "1. Delete all repositories"
    echo -e "2. Review repositories one by one"
    echo -e "3. Return to main menu"
    read -p "Enter your choice [1-3]: " choice
    
    case $choice in
        1)
            echo -e "${RED}WARNING: This will delete all up-to-date repositories!${NC}"
            read -p "Are you sure you want to continue? (y/n): " confirm
            
            if [ "$confirm" == "y" ]; then
                bash prompt_and_delete_repo.sh
            fi
            ;;
        2)
            while IFS= read -r folder; do
                if [ -z "$folder" ] || [ ! -d "$folder" ]; then
                    continue
                fi
                
                echo -e "\n${GREEN}Repository: ${folder}${NC}"
                
                echo -e "${YELLOW}Options:${NC}"
                echo "1. Delete repository"
                echo "2. Skip repository"
                echo "3. Return to main menu"
                read -p "Enter your choice [1-3]: " repo_choice
                
                case $repo_choice in
                    1)
                        echo "Deleting repository..."
                        rm -rf "$folder"
                        ;;
                    2)
                        echo "Skipping repository..."
                        ;;
                    3)
                        return
                        ;;
                esac
            done < stats_myrepo_everything_uptodate.txt
            ;;
        *)
            return
            ;;
    esac
    
    echo -e "\n${GREEN}All up-to-date repositories have been processed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to process a specific folder
process_specific_folder() {
    echo -e "${GREEN}Process a specific folder...${NC}"
    
    echo -n "Enter the path to the folder: "
    read -r folder_path
    
    if [ ! -d "$folder_path" ]; then
        echo -e "${RED}Folder does not exist!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}Options for ${folder_path}:${NC}"
    echo "1. Analyze folder"
    echo "2. Version folder (create new repo)"
    echo "3. Fork existing repo"
    echo "4. Save pending changes"
    echo "5. Return to main menu"
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1)
            echo "Analyzing folder..."
            collect_requirements "$folder_path"
            ;;
        2)
            local owner
            choose_owner
            owner=$SELECTED_OWNER
            
            repo_name=$(basename "$folder_path")
            create_github_repo "$repo_name" "$owner"
            bash version_this_folder.sh "$folder_path" "https://github.com/${owner}/${repo_name}.git"
            ;;
        3)
            local owner
            choose_owner
            owner=$SELECTED_OWNER
            
            bash fork_existing_repo.sh "$owner" "$folder_path"
            ;;
        4)
            cd "$folder_path" || return
            
            if test -f ".env"; then
                echo "Copying the .env file"
                cp .env .env.migrated_from_mac
            fi
            
            generate_gitignore "$folder_path"
            encrypt_sensitive_files "$folder_path"
            
            git switch -c "migration_from_my_mac-$(date +'%Y%m%d-%H%M%S')"
            git add .
            git commit -m 'data migrated from my mac'
            git push --set-upstream origin "migration_from_my_mac-$(date +'%Y%m%d-%H%M%S')"
            
            cd - > /dev/null
            ;;
        *)
            return
            ;;
    esac
    
    echo -e "\n${GREEN}Folder processed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to cleanup Downloads folder
cleanup_downloads() {
    echo -e "${GREEN}Cleaning up Downloads folder...${NC}"
    
    # Define Downloads directories
    DOWNLOADS_DIR="/Users/sergio/Downloads"
    TO_TRIAGE_DIR="${DOWNLOADS_DIR}/to_triage"
    TO_DELETE_DIR="${DOWNLOADS_DIR}/to_delete"
    
    # Create necessary directories
    mkdir -p "$TO_TRIAGE_DIR"
    mkdir -p "$TO_DELETE_DIR"
    
    echo -e "${BLUE}Options:${NC}"
    echo "1. Organize Downloads folder (move files to to_triage)"
    echo "2. Process to_triage folder"
    echo "3. Cleanup to_delete folder"
    echo "4. Return to main menu"
    read -p "Enter your choice [1-4]: " choice
    
    case $choice in
        1)
            echo "Organizing Downloads folder..."
            # Move all files and folders (except to_triage and to_delete) to to_triage
            find "$DOWNLOADS_DIR" -maxdepth 1 -not -path "$DOWNLOADS_DIR" -not -path "$TO_TRIAGE_DIR" -not -path "$TO_DELETE_DIR" | while read -r item; do
                echo "Moving $(basename "$item") to to_triage..."
                mv "$item" "$TO_TRIAGE_DIR/"
            done
            ;;
        2)
            echo "Processing to_triage folder..."
            # List all files in to_triage and let user decide what to do with each
            find "$TO_TRIAGE_DIR" -maxdepth 1 -not -path "$TO_TRIAGE_DIR" | while read -r item; do
                echo -e "\n${YELLOW}Processing: $(basename "$item")${NC}"
                
                # Open file explorer for the item if it's a folder
                if [ -d "$item" ]; then
                    explore_folder "$item"
                fi
                
                echo -e "${BLUE}Options:${NC}"
                echo "1. Keep this item (specify destination)"
                echo "2. Move to to_delete folder"
                echo "3. Skip this item"
                echo "4. Exit to main menu"
                read -p "Enter your choice [1-4]: " item_choice
                
                case $item_choice in
                    1)
                        echo -n "Enter destination path: "
                        read -r destination
                        
                        if [ ! -d "$destination" ]; then
                            echo "Creating directory: $destination"
                            mkdir -p "$destination"
                        fi
                        
                        echo "Moving $(basename "$item") to $destination..."
                        mv "$item" "$destination/"
                        ;;
                    2)
                        echo "Moving $(basename "$item") to to_delete..."
                        mv "$item" "$TO_DELETE_DIR/"
                        ;;
                    3)
                        echo "Skipping item..."
                        ;;
                    4)
                        return
                        ;;
                esac
            done
            ;;
        3)
            echo "Cleaning up to_delete folder..."
            
            # Check if to_delete folder is empty
            if [ -z "$(ls -A "$TO_DELETE_DIR")" ]; then
                echo "The to_delete folder is empty."
                read -p "Press Enter to continue..."
                return
            fi
            
            echo -e "${RED}WARNING: This will permanently delete all files in the to_delete folder!${NC}"
            read -p "Are you sure you want to continue? (y/n): " confirm
            
            if [ "$confirm" == "y" ]; then
                echo "Deleting all files in to_delete folder..."
                rm -rf "${TO_DELETE_DIR:?}/"*
            fi
            ;;
        *)
            return
            ;;
    esac
    
    echo -e "\n${GREEN}Downloads cleanup completed.${NC}"
    read -p "Press Enter to continue..."
}

# Function to show statistics
show_statistics() {
    echo -e "${GREEN}Cleanup Statistics${NC}"
    
    # Count repositories by status
    local not_init=$(grep -c . stats_local_folder_not_a_repo.txt 2>/dev/null || echo 0)
    local external=$(grep -c . stats_external_repo_to_fork.txt 2>/dev/null || echo 0)
    local changes=$(grep -c . stats_myrepo_changes_to_save.txt 2>/dev/null || echo 0)
    local uptodate=$(grep -c . stats_myrepo_everything_uptodate.txt 2>/dev/null || echo 0)
    
    # Calculate processed repositories
    local total=$((not_init + external + changes + uptodate))
    local completed=$(find "$COMPLETED_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
    
    # Get Downloads folder statistics
    local to_triage=$(find "/Users/sergio/Downloads/to_triage" -maxdepth 1 -mindepth 1 | wc -l)
    local to_delete=$(find "/Users/sergio/Downloads/to_delete" -maxdepth 1 -mindepth 1 | wc -l)
    
    echo -e "\n${BLUE}Repository Status:${NC}"
    echo -e "Folders not initialized as Git repos: ${not_init}"
    echo -e "External repos to fork: ${external}"
    echo -e "My repos with changes to save: ${changes}"
    echo -e "Repos up-to-date: ${uptodate}"
    echo -e "Total repositories: ${total}"
    echo -e "Completed repositories: ${completed}"
    echo -e "Progress: $((completed * 100 / (total > 0 ? total : 1)))%"
    
    echo -e "\n${BLUE}Downloads Folder:${NC}"
    echo -e "Files/folders in to_triage: ${to_triage}"
    echo -e "Files/folders in to_delete: ${to_delete}"
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        0)
            echo "Exiting..."
            exit 0
            ;;
        1)
            analyze_dev_folder
            ;;
        2)
            process_uninit_repos
            ;;
        3)
            process_external_repos
            ;;
        4)
            save_pending_changes
            ;;
        5)
            cleanup_uptodate_repos
            ;;
        6)
            process_specific_folder
            ;;
        7)
            cleanup_downloads
            ;;
        8)
            show_statistics
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 1
            ;;
    esac
done