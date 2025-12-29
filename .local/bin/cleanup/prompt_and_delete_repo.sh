

RED='\e[0;31m'
NC='\e[0m' # No Color

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White


# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White

GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
NC=$'\e[0m'

CURRENT_FOLDER=$(pwd)
SRC_FILE=$CURRENT_FOLDER/stats_myrepo_everything_uptodate.txt

TTY=`tty`

while IFS= read -r line
do
  if [[ ! -d "$line" ]]; then
    echo "Folder $line does not existing. move to the next ..."
    # exit 0
    continue
  fi

  echo ""
  echo "Moving into the folder ${RED}$line${NC}"
  #cd $line
  git -C $line status --ignored
  echo ""


  NBCHANGES=$(git -C $line status --ignored -suno | wc -l | tr -s '[:blank:]')
  NBUNTRACKED=$(git -C $line ls-files --others --exclude-standard | wc -l | tr -s '[:blank:]')
  REMOTE_URL=$(git -C $line ls-remote --get-url origin)

  echo ""
  echo "You have ${RED}$NBCHANGES${NC} tracked changes"
  echo "You have ${RED}$NBUNTRACKED${NC} untracked changes"
  echo "Repote url = ${RED}$REMOTE_URL${NC}"
  echo ""

  # echo ""
  # echo "${BIGreen}Create a brand new repository for this one${NC}"
  # echo ""
  # REPO_IS_MYACCOUNT=0
  # if [[ $REMOTE_URL == *"https://github.com/fullbright"* || $REMOTE_URL == *"https://github.com/BrightSoftwares"* || $REMOTE_URL == *"https://github.com/sergioafanou"* ]]; then
  #   echo "The repo is one of mine."
  #   REPO_IS_MYACCOUNT=1
  # fi

  # echo "$REPO_IS_MYACCOUNT"
  # if [[ $REPO_IS_MYACCOUNT == 1 ]]; then
  #   echo "The repo $REMOTE_URL is one of my repos. Not creating a new repo"
  # else
  #   echo "The repo $REMOTE_URL is NOT mine. Must create one for it."
  #   # exit
  # fi


  # echo ""
  # echo "${BIBlue}Commit pending changes${NC}"
  # echo ""


  # while true; do
  #   read -p "Do you want force add the untracked files? " yn
  #   case $yn in
  #       [Yy]* ) echo "force adding untracked files"; git add -f .; git commit -m 'force adding changes on the macbook'; break;;
  #       [Nn]* ) break;;
  #       * ) echo "Please answer yes or no.";;
  #   esac
  # done



  #   echo "We have changes to commit or untracked files to track."
  #   if test -f ".env"; then
  #     echo "Copying the .env file"
  #     cp .env .env.migrated_from_mac
  #   fi

  #   git switch -c migration_from_my_mac_june2024
  #   git add .
  #   git commit -m 'data migrated from my mac'
  #   git pull --rebase origin migration_from_my_mac_june2024
  #   git push --set-upstream origin migration_from_my_mac_june2024
  #   echo ""

  echo "Here is the content of the folder and the branch"
  git -C $line status --ignored

  echo ""
  echo "${RED}HEADS UP! Destructive action${NC}"
  echo ""
  while true; do
      read -p "Do you want to delete the folder $line? " yn <$TTY
      case $yn in
          [Yy]* ) echo "deleting the folder $line"; rm -rf $line; break;;
          # [Nn]* ) exit;;
          [Nn]* ) break;;
          * ) echo "Please answer yes or no.";;
      esac
  done
done < "$SRC_FILE"


cd /Users/sergio/

