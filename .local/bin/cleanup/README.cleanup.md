# How to cleanup the to_triage and to_delete folder

1. Go to the Downloads folder, then go to the to_triage folder
2. Sort all the files in there
   Each file must go to its destination
   If the file is for a project that is not created yet, create the project folder and move the file or filder inside
   You can encrypt the sensitive files using GnuPG before adding them to version control or add them to drive
   For the files/folders that must be deleted, move them to the to_delete folder. An automated process will clean them up automatically after 90 days.

# How to cleanup using scripts

Navigate ti /Users/sergio

Run this command

ll -la stats\_\*

You will see the list of all the files that contain repos to process

To generate these files, run this script

`bash collect_requirements.sh dev`

## Process the repos local not initialized

For each line in the file `stats_local_folder_not_a_repo.txt`

- create a repo in github
- copy the https url
- run this command

bash version_this_folder.sh dev/afroshop228_backup https://github.com/BrightSoftwares/afroshop228_backup.git

Replace the folder and the github url with the right ones.

## process the repos to fork

Cat the content of this file

cat stats_external_repo_to_fork.txt

For each folder in this file:

- create a repo in github
- ciopy the url
- execute this command

~~bash fork_existing_repo.sh dev/Text-Rewrite-NLP https://github.com/BrightSoftwares/Text-Rewrite-NLP.git~~
bash fork_existing_repo.sh <github-owner> <path-to-folder>

## Process the repos with changes to save

Same thing as before.

cat stats_myrepo_changes_to_save.txt

Run this command:

`bash save_pending_changes.sh`

It will go through all the folder in the file and save their content to github.
Beware of sensitive keys.

## delete the saved and uploaded repos

while read line; do ./prompt_and_delete_repo.sh $line; done < /Users/sergio/stats_myrepo_everything_uptodate.txt

# How to clean my `dev` folder of my computer

- List all the folders in the dev folder
  - For each folder, determine the final status of the repository
    - blank repo to keep, and save the content of it
    - forked repo and save in my personal github account
    - my repo: repo exists but has existing modifications to save
    - another user repo: repo exists but has existing modifications to save
  - Inputs that the user must give
    - is this folder a repo? if yes, then we can check further, if no, we ask if we can delete it.
    - do you want to delete the folder?
    - do you want to create a forked of the current repository and save the modifications?
    - do you want to create a new repository and save the content inside?
    -

# Workflow

- is a repo?
- is my account the owner?
  no -> do I want to keep this repository? Possible to list the content of the folder
  yes -> fork this repository, the repo is now ours
  recheck if the repo is ours (code it as a function)
  yes -> do we have changes to keep?
  yes -> create a branch and save the changes there
  no -> do nothing
- should we delete the folder? y/n?

# Flow of repos

Buckets

1. All the folders
2. All Repositories
3. Repositories that I need to delete
4. Repositories that I need to keep
   4.1. Repositories that have changes to save
   4.2. Repositories without changes
5. Repositories that I own
6. Repositories that have been processed.

# How to clean the downloads folder

- Go to the Downloads/to_delete folder
  - For each folder, check if it needs to be kept.
    If yes, move it to a location where you know that it will be processed
    If no, leave it there, it will be automatically purged
- Setup an automatic purge using the python organize tool

- Go to the Downloads folder
  - For each file/folder, check if it must be kept.
    If yes, move it to the location where you know that it will be processed
    if no, move it to the to_delete folder
