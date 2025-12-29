#!/bin/bash

FOLDER_TO_PROCESS=$1
REPO_URL=$2
CURRENT_FOLDER=$(pwd)

# SRC_FILE=$CURRENT_FOLDER/stats_myrepo_changes_to_save.txt

# echo "Processing file $SRC_FILE"

echo "Current folder $CURRENT_FOLDER"
echo ""

echo "Processing folder $FOLDER_TO_PROCESS"

cd $FOLDER_TO_PROCESS

echo "Attempting to detect large files to avoid git LFS"
NB_LARGE_FILES=$(find . -size +50M | wc -l)
echo "There are $NB_LARGE_FILES large files."
find . -size +50M

while true; do
  read -p "Do you want force add the untracked files? " yn
  case $yn in
      [Yy]* ) echo "force versionning the folder"; git init; git add . ; git commit -m "first commit"; git branch -M main; git remote add origin $REPO_URL; git push -u origin main; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
  esac
done




echo "Going back to folder $CURRENT_FOLDER"
cd $CURRENT_FOLDER

