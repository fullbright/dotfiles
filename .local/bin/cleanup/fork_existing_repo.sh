#!/bin/bash

GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
NC=$'\e[0m'

source utils_functions.sh

FOLDER_TO_PROCESS=$2
# REPO_URL=$2
owner=$1
CURRENT_FOLDER=$(pwd)

[[ -z "$FOLDER_TO_PROCESS" ]] && { echo "Please provide folder to process" ; exit 1; }
# [[ -z "$2" ]] && { echo "Please provide the repo url" ; exit 1; }
[[ -z "$owner" ]] && { echo "Please provide owner" ; exit 1; }

BRANCH_PREFIX="migration_from_my_mac-$(date +'%Y%m%d-%H%M%S')"
NBCHANGES=$(git -C $FOLDER_TO_PROCESS status --ignored -suno | wc -l | tr -s '[:blank:]')
NBUNTRACKED=$(git -C $FOLDER_TO_PROCESS ls-files --others --exclude-standard | wc -l | tr -s '[:blank:]')
REMOTE_URL=$(git -C $FOLDER_TO_PROCESS ls-remote --get-url origin)

echo ""
echo "You have ${RED}$NBCHANGES${NC} tracked changes"
echo "You have ${RED}$NBUNTRACKED${NC} untracked changes"
echo "Repote url = ${RED}$REMOTE_URL${NC}"
echo ""


REPO_IS_MYACCOUNT=0
if [[ $REMOTE_URL == *"https://github.com/fullbright"* || $REMOTE_URL == *"https://github.com/BrightSoftwares"* || $REMOTE_URL == *"https://github.com/sergioafanou"* ]]; then
  echo "The repo is one of mine."
  REPO_IS_MYACCOUNT=1
fi

echo "$REPO_IS_MYACCOUNT"
if [[ $REPO_IS_MYACCOUNT == 1 ]]; then
  echo "The repo ${RED}$REMOTE_URL is one of my repos${NC}. Not creating a new repo"
else
  echo "The repo ${RED}$REMOTE_URL is NOT mine${NC}. Must create one for it."
  # exit
fi


echo "Current folder $CURRENT_FOLDER"
echo ""

echo "Processing folder $FOLDER_TO_PROCESS"

# cd $FOLDER_TO_PROCESS

git -C $FOLDER_TO_PROCESS init


# git remote add origin $REPO_URL
# git remote set-url origin $REPO_URL
# git add .
# git commit -m "first commit, migrated from my mac"
# git branch -M migration_from_my_mac_oct2024
# git push -u origin migration_from_my_mac_oct2024

repo_name=$(basename "$FOLDER_TO_PROCESS")

# echo "Creating new GitHub repository '$owner/$repo_name'..."
# gh repo create "$owner/$repo_name" --public --source="$folder" --remote=origin --confirm
# echo "Repository '$owner/$repo_name' created and linked."
full_repo_name="$owner/$repo_name"
# echo "Repository '$full_repo_name' does not belong to you. Forking repository..."
echo ""
echo "Forking ${RED}$REMOTE_URL${NC} into ${RED}$owner/$repo_name${NC}"
echo "Do you want to continue? (y/n)"
read -r fork_this_repo
if [ "$fork_this_repo" == "y" ]; then
  # Check if it belongs to the user, or fork if not
  if gh repo view "$full_repo_name" &>/dev/null; then
      echo "Repository '$full_repo_name' exists in your GitHub account. No need to fork it..."
  else
      echo "Repository '$full_repo_name' does not belong to you. Forking repository..."

      if [ "$owner" == "fullbright" ]; then
        echo "Forking repo $repo_name for default account $owner"
        gh repo fork "$REMOTE_URL" --clone=false --fork-name $repo_name
      else
        echo "Forking repo $repo_name for organization $owner"
        gh repo fork "$REMOTE_URL" --clone=false --org $owner --fork-name $repo_name
      fi
  fi

  echo ""
  echo "Please copy/paste the new repo owner/reponame"
  read -r owner_repo
  echo ""
  echo "You want to add the following url ${RED}https://github.com/$owner_repo${NC} ? (y/n)"
  read -r confirm_ownerrepo
  if [ "$confirm_ownerrepo" == "y" ]; then
    pwd

    git -C "$FOLDER_TO_PROCESS" remote set-url origin "https://github.com/$owner_repo"
    git -C "$FOLDER_TO_PROCESS" checkout -b "$BRANCH_PREFIX"

    # Step 2: Generate .gitignore and encrypt sensitive files
    generate_gitignore "$FOLDER_TO_PROCESS"
    encrypt_sensitive_files "$FOLDER_TO_PROCESS"

    # Step 3: Commit and push changes
    echo "Committing changes in '$FOLDER_TO_PROCESS' and pushing to branch '$BRANCH_PREFIX'..."
    cd "$FOLDER_TO_PROCESS" || exit
    git add .
    git commit -m "Automated migration commit"
    git push --set-upstream origin "$BRANCH_PREFIX"
    echo "Changes pushed to branch '$BRANCH_PREFIX' in '$full_repo_name'."

    echo "Going back to folder $CURRENT_FOLDER"
  else
    echo "You refused to add this owner_repo"
  fi
else
  echo "You refused to fork that repo"
fi
cd $CURRENT_FOLDER

