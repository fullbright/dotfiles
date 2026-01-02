#!/usr/bin/env bash

GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
NC=$'\e[0m'

source utils_functions.sh


CURRENT_FOLDER=$(pwd)
SRC_FILE=$CURRENT_FOLDER/stats_myrepo_changes_to_save.txt

BRANCH_PREFIX="migration_from_my_mac-$(date +'%Y%m%d-%H%M%S')"

echo "Processing file $SRC_FILE"

echo "Current folder $CURRENT_FOLDER"
echo ""


while IFS= read -r line
do
    echo "${GREEN}Processing folder $line${NC}"
    echo "$line"
    
    cd $line

    echo ">>> ${RED}We have changes to commit${NC} or untracked files to track."
    if test -f ".env"; then
    echo "Copying the .env file"
    cp .env .env.migrated_from_mac
    fi

    generate_gitignore "$line"
    encrypt_sensitive_files "$line"

    git switch -c $BRANCH_PREFIX
    git add .
    git commit -m 'data migrated from my mac'
    # git pull --rebase origin $BRANCH_PREFIX
    git push --set-upstream origin $BRANCH_PREFIX
    echo ""

    echo ">>> Here is the content of the folder and the branch (git status --ignored)"
    git status --ignored

    echo ">>> ${GREEN}Here is the content of the folder ${NC} and the branch (git status)"
    git status


    echo "Going back to folder $CURRENT_FOLDER"
    cd $CURRENT_FOLDER
done < "$SRC_FILE"

