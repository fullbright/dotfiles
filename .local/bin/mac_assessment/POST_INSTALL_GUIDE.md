# 🚀 Post-Installation Restoration Guide

## After Fresh macOS Install

This guide helps you restore your Mac to its previous state after reinstallation. Follow steps in order for best results.

**Estimated Total Time**: 3-6 hours (mostly automated installation time)

---

## Phase 1: Initial Setup (30 minutes)

### 1.1 macOS First-Time Setup
- [ ] Complete Apple's initial setup wizard
- [ ] Sign in with Apple ID
- [ ] Connect to Wi-Fi
- [ ] Set up Touch ID / Face ID
- [ ] Configure privacy settings

### 1.2 System Updates
```bash
# Check for system updates
softwareupdate --list

# Install all available updates
sudo softwareupdate -ia
```
- [ ] Restart if required

### 1.3 Connect External Drive
- [ ] Connect external drive with backups
- [ ] Verify backup directory exists
- [ ] Copy backup to Desktop:
  ```bash
  cp -r /Volumes/EXTERNAL_DRIVE/mac_backup_YYYYMMDD ~/Desktop/
  ```

---

## Phase 2: Essential Tools (30 minutes)

### 2.1 Install Xcode Command Line Tools
```bash
xcode-select --install
```
- [ ] Wait for installation to complete
- [ ] Verify: `xcode-select -p` should show path

### 2.2 Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
- [ ] Follow on-screen instructions
- [ ] Add Homebrew to PATH (instructions will be shown)
- [ ] Run: `brew doctor` to verify

### 2.3 Restore Homebrew Packages
```bash
cd ~/Desktop/mac_backup_YYYYMMDD
brew bundle install --file=./Brewfile
```
- [ ] Wait for all packages to install (15-30 minutes)
- [ ] Verify installations: `brew list`

### 2.4 Install Mac App Store CLI (mas)
```bash
brew install mas
```
- [ ] Sign in to App Store: `mas signin your@email.com`

---

## Phase 3: Credentials & Security (30 minutes)

### 3.1 Restore SSH Keys
```bash
# Copy SSH keys back
cp -r ~/Desktop/mac_backup_YYYYMMDD/ssh_backup ~/.ssh

# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
chmod 644 ~/.ssh/config
chmod 644 ~/.ssh/known_hosts

# Test SSH key
ssh -T git@github.com
# OR
ssh -T git@gitlab.com
```
- [ ] Verify SSH connection works

### 3.2 Restore GPG Keys
```bash
# Import private keys
gpg --import ~/Desktop/mac_backup_YYYYMMDD/gpg_private_keys.asc

# Import public keys
gpg --import ~/Desktop/mac_backup_YYYYMMDD/gpg_public_keys.asc

# Import trust database
gpg --import-ownertrust ~/Desktop/mac_backup_YYYYMMDD/gpg_trustdb.txt

# Verify
gpg --list-secret-keys
```

### 3.3 Restore Git Configuration
```bash
cp ~/Desktop/mac_backup_YYYYMMDD/gitconfig ~/.gitconfig
cp ~/Desktop/mac_backup_YYYYMMDD/gitignore_global ~/.gitignore_global 2>/dev/null || true

# Verify
git config --list
```

### 3.4 Import Certificates to Keychain
- [ ] Open Keychain Access app
- [ ] Import Apple Developer certificates (.p12 files)
- [ ] Enter passwords when prompted
- [ ] Verify certificates appear in "My Certificates"

---

## Phase 4: Shell & Terminal (15 minutes)

### 4.1 Restore Shell Configuration
```bash
# Restore zsh config
cp ~/Desktop/mac_backup_YYYYMMDD/zshrc ~/.zshrc
source ~/.zshrc

# If using bash
cp ~/Desktop/mac_backup_YYYYMMDD/bashrc ~/.bashrc 2>/dev/null || true
cp ~/Desktop/mac_backup_YYYYMMDD/bash_profile ~/.bash_profile 2>/dev/null || true
```

### 4.2 Restore Config Directory
```bash
rsync -av ~/Desktop/mac_backup_YYYYMMDD/config_backup/ ~/.config/
```

### 4.3 Install Oh My Zsh (Optional)
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Restore your custom .zshrc again if oh-my-zsh overwrote it
cp ~/Desktop/mac_backup_YYYYMMDD/zshrc ~/.zshrc
source ~/.zshrc
```

---

## Phase 5: Development Environment (60 minutes)

### 5.1 Install Xcode (If needed for iOS/macOS development)
```bash
# Option 1: From App Store
mas install 497799835  # Xcode

# Option 2: Download from developer.apple.com
```
- [ ] Launch Xcode and accept license
- [ ] Install additional components if prompted

### 5.2 Restore Xcode Data
```bash
# Restore UserData (snippets, keybindings, themes)
rsync -av ~/Desktop/mac_backup_YYYYMMDD/xcode_userdata/ ~/Library/Developer/Xcode/UserData/

# Restore provisioning profiles
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
rsync -av ~/Desktop/mac_backup_YYYYMMDD/provisioning_profiles/ ~/Library/MobileDevice/Provisioning\ Profiles/

# Restore archives (optional - large files)
# rsync -av ~/Desktop/mac_backup_YYYYMMDD/xcode_archives/ ~/Library/Developer/Xcode/Archives/
```

### 5.3 Install Node.js & npm
```bash
# Already installed via Homebrew, or use nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Load nvm
source ~/.zshrc

# Install Node LTS
nvm install --lts
nvm use --lts
```

### 5.4 Restore npm Global Packages
```bash
# Install packages from list
cat ~/Desktop/mac_backup_YYYYMMDD/npm_global_packages.txt | awk '{print $1}' | xargs npm install -g
```

### 5.5 Install Python Packages
```bash
# Restore pip packages
pip3 install -r ~/Desktop/mac_backup_YYYYMMDD/pip_packages.txt
```

### 5.6 Install Ruby Gems
```bash
# Restore gems
cat ~/Desktop/mac_backup_YYYYMMDD/gem_packages.txt | awk '{print $1}' | xargs gem install
```

### 5.7 Install VS Code Extensions
```bash
# Restore VS Code settings
rsync -av ~/Desktop/mac_backup_YYYYMMDD/vscode_user/ ~/Library/Application\ Support/Code/User/

# Install extensions
cat ~/Desktop/mac_backup_YYYYMMDD/vscode_extensions.txt | xargs -n 1 code --install-extension
```

### 5.8 Restore Other IDEs
```bash
# JetBrains IDEs
rsync -av ~/Desktop/mac_backup_YYYYMMDD/jetbrains/ ~/Library/Application\ Support/JetBrains/

# Android Studio
rsync -av ~/Desktop/mac_backup_YYYYMMDD/android_studio/ ~/Library/Application\ Support/Google/AndroidStudio/

# Sublime Text
rsync -av ~/Desktop/mac_backup_YYYYMMDD/sublime/ ~/Library/Application\ Support/Sublime\ Text/
```

---

## Phase 6: Browsers & Profiles (30 minutes)

### 6.1 Restore Chrome Profile
```bash
# Close Chrome if running
killall "Google Chrome" 2>/dev/null || true

# Restore profile
rsync -av ~/Desktop/mac_backup_YYYYMMDD/chrome_backup/ ~/Library/Application\ Support/Google/Chrome/

# Launch Chrome and verify
open -a "Google Chrome"
```
- [ ] Check extensions loaded
- [ ] Check bookmarks restored
- [ ] Sign in to Chrome Sync (optional)

### 6.2 Restore Firefox Profile
```bash
# Close Firefox if running
killall Firefox 2>/dev/null || true

# Restore profile
rsync -av ~/Desktop/mac_backup_YYYYMMDD/firefox_backup/ ~/Library/Application\ Support/Firefox/

# Launch Firefox
open -a Firefox
```

### 6.3 Restore Safari Data
```bash
rsync -av ~/Desktop/mac_backup_YYYYMMDD/safari_backup/ ~/Library/Safari/
```

---

## Phase 7: Applications (60 minutes)

### 7.1 Install Mac App Store Apps
```bash
# Reference your backup list
cat ~/Desktop/mac_backup_YYYYMMDD/04_mac_app_store.txt

# Install apps by ID (from the list)
# Example: mas install 441258766  # Magnet
```

### 7.2 Install Additional Applications
- [ ] Reference `05_all_applications.txt` for complete list
- [ ] Download and install apps not in Homebrew/App Store:
  - [ ] Licensed software (with license keys)
  - [ ] Company-specific tools
  - [ ] Custom installers

### 7.3 Sign In to Applications
- [ ] Email clients
- [ ] Slack, Discord, Teams
- [ ] Adobe Creative Cloud
- [ ] Microsoft Office
- [ ] Other licensed software

---

## Phase 8: Databases (30 minutes)

### 8.1 Restore PostgreSQL
```bash
# Install PostgreSQL (should be from Brewfile)
brew services start postgresql

# Restore database
psql -f ~/Desktop/mac_backup_YYYYMMDD/postgresql_backup.sql postgres
```

### 8.2 Restore MySQL
```bash
# Start MySQL
brew services start mysql

# Restore databases
mysql -u root < ~/Desktop/mac_backup_YYYYMMDD/mysql_backup.sql
```

### 8.3 Restore MongoDB
```bash
# Start MongoDB
brew services start mongodb-community

# Restore databases
mongorestore ~/Desktop/mac_backup_YYYYMMDD/mongodb_backup
```

---

## Phase 9: Personal Files (30 minutes)

### 9.1 Restore Documents
```bash
rsync -av ~/Desktop/mac_backup_YYYYMMDD/documents_backup/ ~/Documents/
```

### 9.2 Restore .env Files
```bash
# Review list
cat ~/Desktop/mac_backup_YYYYMMDD/env_files_list.txt

# Copy .env files back to their original locations
# (Manual step - copy each file to its project)
```

### 9.3 Clone Git Repositories
```bash
# Create directory for projects
mkdir -p ~/Projects
cd ~/Projects

# Clone your repositories (example)
# Refer to 02_git_repositories.txt for complete list
git clone git@github.com:username/repo1.git
git clone git@github.com:username/repo2.git
# ... etc
```

### 9.4 Restore Local-Only Projects
```bash
cp -r ~/Desktop/mac_backup_YYYYMMDD/local_projects/* ~/Projects/
```

---

## Phase 10: System Preferences (30 minutes)

### 10.1 Manual System Preferences
Use your screenshots as reference:

**Dock**
- [ ] Position on screen
- [ ] Icon size
- [ ] Magnification
- [ ] Auto-hide

**Trackpad**
- [ ] Tap to click
- [ ] Tracking speed
- [ ] More gestures

**Keyboard**
- [ ] Key repeat rate
- [ ] Delay until repeat
- [ ] Shortcuts

**Mission Control**
- [ ] Hot corners
- [ ] Keyboard shortcuts

### 10.2 Finder Preferences
- [ ] Show filename extensions
- [ ] Show hidden files: `defaults write com.apple.finder AppleShowAllFiles YES`
- [ ] Restart Finder: `killall Finder`

### 10.3 Additional Settings
```bash
# Enable key repeat for VS Code
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

# Show full path in Finder title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool YES

# Disable dashboard
defaults write com.apple.dashboard mcx-disabled -boolean YES

# Restart affected services
killall Dock
killall Finder
```

---

## Phase 11: Final Verification (30 minutes)

### 11.1 Test Development Environment
- [ ] Open terminal and verify shell config loaded
- [ ] Test git: `git status` in a repo
- [ ] Test SSH: `ssh -T git@github.com`
- [ ] Test Node: `node -v && npm -v`
- [ ] Test Python: `python3 --version`
- [ ] Build a sample project

### 11.2 Test Applications
- [ ] Launch each important application
- [ ] Verify licenses activated
- [ ] Test browsers with extensions
- [ ] Check database connections

### 11.3 Verify Credentials
- [ ] SSH keys working
- [ ] GPG signing works: `echo "test" | gpg --clearsign`
- [ ] Git commits signed (if using GPG)
- [ ] API keys and tokens working

---

## Phase 12: Cleanup (15 minutes)

### 12.1 Remove Backup from Desktop
```bash
# ONLY after verifying everything works!
# Move to external drive for archival
mv ~/Desktop/mac_backup_YYYYMMDD /Volumes/EXTERNAL_DRIVE/

# Or delete if you have multiple backup copies
# rm -rf ~/Desktop/mac_backup_YYYYMMDD
```

### 12.2 Set Up Time Machine
- [ ] Connect Time Machine drive
- [ ] System Preferences → Time Machine
- [ ] Enable automatic backups

### 12.3 Final System Update
```bash
sudo softwareupdate -ia
```

---

## 🎉 Restoration Complete!

Your Mac should now be restored to its previous state with a fresh macOS installation.

### Post-Restoration Checklist
- [ ] All applications installed and working
- [ ] All credentials and keys working
- [ ] Development environment functional
- [ ] Git repositories cloned and accessible
- [ ] Databases restored
- [ ] Browser data and extensions working
- [ ] System preferences configured
- [ ] Time Machine backup enabled

---

## 📝 Notes & Troubleshooting

### Common Issues

**SSH Key Permission Issues**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

**Git GPG Signing Errors**
```bash
# Configure GPG for git
git config --global gpg.program $(which gpg)
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_KEY_ID
```

**Homebrew Permission Errors**
```bash
sudo chown -R $(whoami) /usr/local/share
```

**VS Code Can't Find Extensions**
```bash
# Manually reinstall extensions
code --install-extension <extension-id>
```

---

## 🆘 Need Help?

- Review assessment reports: `~/mac_assessment_report_*/`
- Check backup directory: `~/Desktop/mac_backup_YYYYMMDD/`
- macOS Recovery: Restart and hold Cmd+R
- Apple Support: 1-800-MY-APPLE

---

**Time to Celebrate!** 🎊 You've successfully reinstalled and restored your Mac!
