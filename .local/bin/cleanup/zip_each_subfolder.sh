#!/usr/bin/env bash


[[ -z "$1" ]] && { echo "Please provide the folder to process" ; exit 1; }

if ! command -v zip &> /dev/null
then
    echo "The 'zip' command could not be found. Please install zip application"
    exit 1
fi

FOLDER_TO_PROCESS=$1
echo "Folder to process is $FOLDER_TO_PROCESS"

CURRENT_FOLDER=$(pwd)
echo "Current folder is $CURRENT_FOLDER"

echo "Moving inside the folder to process"
cd $FOLDER_TO_PROCESS

#echo "Rename the folder to remove the space from their names"
#find . -depth -name "* *" -execdir rename 's/ /./g' "{}" \;

echo "Zipping the folders"
for i in */; do zip -r "${i%/}.zip" "$i"; done

echo "Done"
echo "Moving back to the current folder"
cd $CURRENT_FOLDER
