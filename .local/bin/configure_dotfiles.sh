#!/usr/bin/env bash

git clone --bare https://github.com/fullbright/dotfiles.git $HOME/.dotfiles_bare

function dotfiles {
   /usr/bin/git --git-dir=$HOME/.dotfiles_bare/ --work-tree=$HOME $@
}

mkdir -p .dotfiles-backup

dotfiles checkout

if [ $? = 0 ]; then
  echo "Checked out config.";
  else
    echo "Backing up pre-existing dot files.";
    dotfiles checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .dotfiles-backup/{}
fi;

dotfiles checkout
dotfiles config status.showUntrackedFiles no
