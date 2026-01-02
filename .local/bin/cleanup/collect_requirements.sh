#!/usr/bin/env bash

function collect_requirements(){
    FOLDER_TO_PROCESS=$1
    echo "Collecting the requirements for the folder $FOLDER_TO_PROCESS"

    

    echo "Moving into the folder $FOLDER_TO_PROCESS"
    cd $FOLDER_TO_PROCESS
    echo "Current folder is "
    pwd

    echo "Checking if folder is a git repo"
    IS_GIT_REPO=0
    if [ -d .git ]; then
        echo .git;
        echo "This is a git repo."
        IS_GIT_REPO=1
    else
        echo "Not a git repo"
        IS_GIT_REPO=0
        echo "Folder to process"
        echo $FOLDER_TO_PROCESS
        FILE=$CURRENT_FOLDER/stats_local_folder_not_a_repo.txt
        echo "Pushing folder $FOLDER_TO_PROCESS to file $FILE"
        echo -e "$FOLDER_TO_PROCESS" >> $FILE
        # echo "$(cat $FILE)$FOLDER_TO_PROCESS" >> $FILE
        # echo "Onrone" > $FILE
        git rev-parse --git-dir 2> /dev/null;
        return 0
    fi;


    NBCHANGES=$(git status --ignored -suno | wc -l | tr -s '[:blank:]')
    NBUNTRACKED=$(git ls-files --others --exclude-standard | wc -l | tr -s '[:blank:]')
    REMOTE_URL=$(git ls-remote --get-url origin)

    REPO_IS_MYACCOUNT=0
    if [[ $REMOTE_URL == *"https://github.com/fullbright"* || $REMOTE_URL == *"https://github.com/BrightSoftwares"* || $REMOTE_URL == *"https://github.com/sergioafanou"* ]]; then
        echo "The repo is one of mine."
        REPO_IS_MYACCOUNT=1
    fi

    echo "Is repo in my account = $REPO_IS_MYACCOUNT"
    if [[ $REPO_IS_MYACCOUNT == 1 ]]; then
        echo "The repo $REMOTE_URL is one of my repos. Not creating a new repo"
    else
        echo "The repo $REMOTE_URL is NOT mine. Must create one for it."
        FILE=$CURRENT_FOLDER/stats_external_repo_to_fork.txt
        echo "Pushing folder $FOLDER_TO_PROCESS to file $FILE"
        echo -e "$FOLDER_TO_PROCESS" >> $FILE
        # echo "$(cat $FILE)$FOLDER_TO_PROCESS" >> $FILE
        # echo "Onroneexternal" >> stats_external_repo_to_fork.txt # $FILE
        return 0
    fi

    echo "Checking if I have pending changes"
    if [[ $NBCHANGES -gt 0 || $NBUNTRACKED -gt 0 ]]; then
        FILE=$CURRENT_FOLDER/stats_myrepo_changes_to_save.txt
        echo "Pushing folder $FOLDER_TO_PROCESS to file $FILE"
        echo -e "$FOLDER_TO_PROCESS" >> $FILE
        # echo "$(cat $FILE)$FOLDER_TO_PROCESS" >> $FILE
        # echo "Onrone tosave" >> $FILE
        return 0
    else
        FILE=$CURRENT_FOLDER/stats_myrepo_everything_uptodate.txt
        echo "Pushing folder $FOLDER_TO_PROCESS to file $FILE"
        echo -e "$FOLDER_TO_PROCESS" >> $FILE
        # echo "$(cat $FILE)$FOLDER_TO_PROCESS" >> $FILE
        # echo "Onrone everyhtinhg" >> $FILE
    fi


    

}

[[ -z "$1" ]] && { echo "Please provide the folder to analyze" ; exit 1; }

CURRENT_FOLDER=$(pwd)
echo "Empty the result files"
echo "" > $CURRENT_FOLDER/stats_local_folder_not_a_repo.txt
echo "" > $CURRENT_FOLDER/stats_external_repo_to_fork.txt
echo "" > $CURRENT_FOLDER/stats_myrepo_changes_to_save.txt
echo "" > $CURRENT_FOLDER/stats_myrepo_everything_uptodate.txt


echo "Collecting infos from the folder $1"
for d in $1/*/ ; do
    echo "Current folder $CURRENT_FOLDER"
    echo ""
    
    echo "$d"
    #repository_infos $d
    collect_requirements $d
    #echo "cecececececece" | tee -a stats_external_repo_to_fork.txt

    echo "Going back to folder $CURRENT_FOLDER"
    cd $CURRENT_FOLDER
done



echo ""
echo "You have $NBCHANGES tracked changes"
echo "You have $NBUNTRACKED untracked changes"
echo "Repote url = $REMOTE_URL"
echo "Repo is in my account? $REPO_IS_MYACCOUNT"
echo "Folder is a git repo? $IS_GIT_REPO"
echo ""

