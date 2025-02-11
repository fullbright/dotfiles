#!/bin/bash


function repository_infos(){
  echo "Collecting infos for the repository $1"
  CURRENT_FOLDER=$(pwd)
  echo "Current folder $CURRENT_FOLDER"
  echo ""

  cd $1
  
  NBCHANGES=$(git status -suno | wc -l)
  echo "Nb peding changes = $NBCHANGES"

  NBUNTRACKED=$(git ls-files --others --exclude-standard | wc -l)
  echo "Nb untracked files = $NBUNTRACKED"

  REMOTE_URL=$(git ls-remote --get-url origin)
  echo "Remote Url = $REMOTE_URL"
  
  
  echo "List of pending repositories"
  git ls-remote --get-url origin
  
  echo "List of untracked files"
  git ls-files --others --exclude-standard
  
  
  git status
  git remote show origin

  echo "Going back to folder $CURRENT_FOLDER"
  cd $CURRENT_FOLDER
}

[[ -z "$1" ]] && { echo "Please provide the folder to analyze" ; exit 1; }

echo "Analyzing the folder $1"
for d in $1/*/ ; do
    echo "$d"
    repository_infos $d
done

echo ""
echo ""
echo "====================="

