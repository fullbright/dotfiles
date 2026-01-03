# 📋 Pre-Reinstall Checklist

## Before You Begin

**STOP!** Don't wipe your Mac until you've completed ALL items below.

**Estimated Time**: 2-4 hours (depending on data volume)

---

## Phase 1: Assessment (30 minutes)

### 1.1 Run Assessment Script
- [ ] Navigate to `~/.local/bin/mac_assessment/`
- [ ] Run: `chmod +x assess_mac_data.sh`
- [ ] Run: `./assess_mac_data.sh`
- [ ] Wait for completion (5-15 minutes)
- [ ] Review: `00_SUMMARY.txt` report

### 1.2 Review Critical Reports
- [ ] Open `02_git_repositories.txt` - Check for uncommitted changes
- [ ] Open `08_sensitive_files.txt` - Review all credentials
- [ ] Open `12_app_development.txt` - Check developer certificates
- [ ] Open `06_browser_profiles.txt` - Note profile locations

### 1.3 Create Backup Directory
```bash
mkdir -p ~/Desktop/mac_backup_$(date +%Y%m%d)
cd ~/Desktop/mac_backup_$(date +%Y%m%d)
```

---

## Phase 2: Source Code & Git (45-60 minutes)

### 2.1 Git Repository Cleanup
- [ ] Review `02_git_repositories.txt` for repos with ⚠️ warnings
- [ ] For each repo with uncommitted changes:
  ```bash
  cd /path/to/repo
  git status
  git add .
  git commit -m "Pre-reinstall backup"
  git push origin HEAD
  ```
- [ ] Verify all repos are pushed: `git log @{u}..`
- [ ] Check for stashes: `git stash list` (apply or document)

### 2.2 Local-Only Projects
- [ ] Identify any projects NOT in git
- [ ] Create git repos or zip archives:
  ```bash
  cd ~/Desktop/mac_backup_YYYYMMDD
  mkdir local_projects
  cp -r /path/to/local/project ./local_projects/
  ```

### 2.3 Database Dumps
- [ ] **PostgreSQL**:
  ```bash
  pg_dumpall > postgresql_backup.sql
  ```
- [ ] **MySQL**:
  ```bash
  mysqldump --all-databases > mysql_backup.sql
  ```
- [ ] **MongoDB**:
  ```bash
  mongodump --out=./mongodb_backup
  ```
- [ ] **SQLite** databases (copy .db files)

---

## Phase 3: Credentials & Security (30 minutes)

### 3.1 SSH Keys
- [ ] Backup all SSH keys:
  ```bash
  cp -r ~/.ssh ~/Desktop/mac_backup_YYYYMMDD/ssh_backup
  ls -la ~/Desktop/mac_backup_YYYYMMDD/ssh_backup
  ```
- [ ] Verify private keys are included (id_rsa, id_ed25519, etc.)
- [ ] Document which key is used for which service

### 3.2 GPG Keys
- [ ] List keys: `gpg --list-secret-keys`
- [ ] Export private keys:
  ```bash
  gpg --export-secret-keys -a > ~/Desktop/mac_backup_YYYYMMDD/gpg_private_keys.asc
  ```
- [ ] Export public keys:
  ```bash
  gpg --export -a > ~/Desktop/mac_backup_YYYYMMDD/gpg_public_keys.asc
  ```
- [ ] Export trust database:
  ```bash
  gpg --export-ownertrust > ~/Desktop/mac_backup_YYYYMMDD/gpg_trustdb.txt
  ```

### 3.3 Keychain Items
- [ ] Open Keychain Access app
- [ ] Review "login" keychain for:
  - [ ] Code signing certificates
  - [ ] Apple Developer certificates
  - [ ] SSH passphrases
  - [ ] API tokens
- [ ] **Export certificates** (Right-click → Export, save as .p12)
- [ ] **Write down passwords** you want to keep (in a secure location!)

### 3.4 Environment Files
- [ ] Search for all .env files:
  ```bash
  find ~ -name ".env*" -type f 2>/dev/null > ~/Desktop/mac_backup_YYYYMMDD/env_files_list.txt
  cat ~/Desktop/mac_backup_YYYYMMDD/env_files_list.txt
  ```
- [ ] Copy all .env files:
  ```bash
  mkdir -p ~/Desktop/mac_backup_YYYYMMDD/env_files
  # Copy each .env file manually to preserve paths
  ```

---

## Phase 4: Development Environment (45 minutes)

### 4.1 Xcode (If using for iOS/macOS development)
- [ ] Backup code snippets:
  ```bash
  rsync -av ~/Library/Developer/Xcode/UserData ~/Desktop/mac_backup_YYYYMMDD/xcode_userdata
  ```
- [ ] Backup archives (for App Store):
  ```bash
  rsync -av ~/Library/Developer/Xcode/Archives ~/Desktop/mac_backup_YYYYMMDD/xcode_archives
  ```
- [ ] Export provisioning profiles:
  ```bash
  rsync -av ~/Library/MobileDevice/Provisioning\ Profiles ~/Desktop/mac_backup_YYYYMMDD/provisioning_profiles
  ```
- [ ] **Export certificates from Keychain Access**:
  - [ ] "Apple Development" certificates
  - [ ] "Apple Distribution" certificates
  - [ ] Save as .p12 files with passwords

### 4.2 VS Code
- [ ] Backup settings:
  ```bash
  rsync -av ~/Library/Application\ Support/Code/User ~/Desktop/mac_backup_YYYYMMDD/vscode_user
  ```
- [ ] Export extensions list:
  ```bash
  code --list-extensions > ~/Desktop/mac_backup_YYYYMMDD/vscode_extensions.txt
  ```
- [ ] Verify extensions list: `cat ~/Desktop/mac_backup_YYYYMMDD/vscode_extensions.txt`

### 4.3 Other IDEs
- [ ] **JetBrains IDEs** (IntelliJ, Android Studio, etc.):
  ```bash
  rsync -av ~/Library/Application\ Support/JetBrains ~/Desktop/mac_backup_YYYYMMDD/jetbrains
  rsync -av ~/Library/Application\ Support/Google/AndroidStudio ~/Desktop/mac_backup_YYYYMMDD/android_studio
  ```
- [ ] **Sublime Text**:
  ```bash
  rsync -av ~/Library/Application\ Support/Sublime\ Text ~/Desktop/mac_backup_YYYYMMDD/sublime
  ```

### 4.4 Package Managers
- [ ] **Homebrew**: (Already in `Brewfile` from assessment)
  ```bash
  cp ~/mac_assessment_report_*/Brewfile ~/Desktop/mac_backup_YYYYMMDD/
  ```
- [ ] **npm global packages**:
  ```bash
  npm list -g --depth=0 > ~/Desktop/mac_backup_YYYYMMDD/npm_global_packages.txt
  ```
- [ ] **pip packages**:
  ```bash
  pip3 list --format=freeze > ~/Desktop/mac_backup_YYYYMMDD/pip_packages.txt
  ```
- [ ] **gem list**:
  ```bash
  gem list > ~/Desktop/mac_backup_YYYYMMDD/gem_packages.txt
  ```

---

## Phase 5: Applications & Preferences (30 minutes)

### 5.1 Application Lists
- [ ] Copy Mac App Store list:
  ```bash
  cp ~/mac_assessment_report_*/04_mac_app_store.txt ~/Desktop/mac_backup_YYYYMMDD/
  ```
- [ ] Copy all applications list:
  ```bash
  cp ~/mac_assessment_report_*/05_all_applications.txt ~/Desktop/mac_backup_YYYYMMDD/
  ```
- [ ] **Document licensed software** you need to reinstall:
  - [ ] License keys
  - [ ] Download links
  - [ ] Activation limits

### 5.2 Browser Data
- [ ] **Chrome**:
  ```bash
  rsync -av ~/Library/Application\ Support/Google/Chrome ~/Desktop/mac_backup_YYYYMMDD/chrome_backup
  ```
- [ ] **Firefox**:
  ```bash
  rsync -av ~/Library/Application\ Support/Firefox ~/Desktop/mac_backup_YYYYMMDD/firefox_backup
  ```
- [ ] **Safari**:
  ```bash
  rsync -av ~/Library/Safari ~/Desktop/mac_backup_YYYYMMDD/safari_backup
  ```
- [ ] **Export bookmarks** from each browser (File → Export)

### 5.3 System Preferences
- [ ] Take screenshots of important preferences:
  - [ ] System Preferences → Keyboard → Shortcuts
  - [ ] System Preferences → Trackpad
  - [ ] System Preferences → Dock
  - [ ] System Preferences → Mission Control
- [ ] **Document any custom settings** you want to restore

---

## Phase 6: Personal Files (30-60 minutes)

### 6.1 Documents
- [ ] Review `~/Documents` for important files
- [ ] Copy any critical documents:
  ```bash
  rsync -av ~/Documents ~/Desktop/mac_backup_YYYYMMDD/documents_backup
  ```

### 6.2 Desktop
- [ ] Clean up Desktop (move important files)
- [ ] Backup Desktop if needed:
  ```bash
  rsync -av ~/Desktop ~/Desktop/mac_backup_YYYYMMDD/desktop_backup
  ```

### 6.3 Downloads
- [ ] Review Downloads folder
- [ ] Keep only what you need

### 6.4 Photos, Music, Videos
- [ ] **Photos**: Use iCloud or external drive
- [ ] **Music**: Use iTunes/Music app backup or iCloud
- [ ] **Videos**: Copy large files to external drive

---

## Phase 7: Dotfiles (15 minutes)

### 7.1 Shell Configuration
- [ ] Backup shell files:
  ```bash
  cp ~/.zshrc ~/Desktop/mac_backup_YYYYMMDD/
  cp ~/.bashrc ~/Desktop/mac_backup_YYYYMMDD/ 2>/dev/null || true
  cp ~/.bash_profile ~/Desktop/mac_backup_YYYYMMDD/ 2>/dev/null || true
  cp ~/.profile ~/Desktop/mac_backup_YYYYMMDD/ 2>/dev/null || true
  ```

### 7.2 Git Configuration
- [ ] Backup git config:
  ```bash
  cp ~/.gitconfig ~/Desktop/mac_backup_YYYYMMDD/
  cp ~/.gitignore_global ~/Desktop/mac_backup_YYYYMMDD/ 2>/dev/null || true
  ```

### 7.3 Other Dotfiles
- [ ] Backup config directory:
  ```bash
  rsync -av ~/.config ~/Desktop/mac_backup_YYYYMMDD/config_backup
  ```
- [ ] List all dotfiles:
  ```bash
  ls -la ~ | grep "^\." > ~/Desktop/mac_backup_YYYYMMDD/dotfiles_list.txt
  ```

---

## Phase 8: Final Verification (30 minutes)

### 8.1 Verify Backups
- [ ] Check backup directory size:
  ```bash
  du -sh ~/Desktop/mac_backup_YYYYMMDD
  ```
- [ ] Verify critical files exist:
  ```bash
  ls -R ~/Desktop/mac_backup_YYYYMMDD | more
  ```

### 8.2 Copy to External Storage
- [ ] **Connect external drive or cloud storage**
- [ ] Copy entire backup:
  ```bash
  rsync -av ~/Desktop/mac_backup_YYYYMMDD /Volumes/EXTERNAL_DRIVE/
  ```
- [ ] **Verify copy completed successfully**
- [ ] Keep a second copy in cloud (Dropbox, Google Drive, etc.)

### 8.3 Create Archive
- [ ] Create compressed archive:
  ```bash
  cd ~/Desktop
  tar -czf mac_backup_$(date +%Y%m%d).tar.gz mac_backup_$(date +%Y%m%d)
  ```
- [ ] Copy archive to external drive

### 8.4 Document Everything
- [ ] Create a restoration plan (see `POST_INSTALL_GUIDE.md`)
- [ ] Write down any special configurations or setups
- [ ] Document installation order for applications

---

## Phase 9: Cloud Sync Verification (15 minutes)

### 9.1 Cloud Services
- [ ] **iCloud**: Verify all files synced
- [ ] **Dropbox**: Check sync status
- [ ] **Google Drive**: Verify upload complete
- [ ] **OneDrive**: Check sync status
- [ ] **GitHub/GitLab**: All repos pushed
- [ ] **Time Machine**: Run one final backup

### 9.2 Sign Out of Services
- [ ] Sign out of iCloud (optional, but recommended)
- [ ] Sign out of licensed software (Adobe, Microsoft, etc.)
- [ ] Deauthorize iTunes/Music
- [ ] Sign out of email clients

---

## Phase 10: Final Checks (15 minutes)

### 10.1 Review Checklist
- [ ] Review this entire checklist - all items checked?
- [ ] Review assessment reports one more time
- [ ] Verify backups on external drive
- [ ] Verify cloud syncs complete

### 10.2 Test Restoration (Recommended)
- [ ] Try restoring one small item (e.g., .zshrc)
- [ ] Verify SSH keys can be copied back
- [ ] Check that archives can be extracted

### 10.3 Ready to Reinstall
- [ ] You have TWO copies of backups (local + external/cloud)
- [ ] All git repos committed and pushed
- [ ] All credentials and keys backed up
- [ ] License keys documented
- [ ] Restoration plan created

---

## ✅ Checklist Complete!

You're now ready to reinstall macOS safely. Follow the `POST_INSTALL_GUIDE.md` after reinstallation to restore your system.

**Remember**: Keep your backup drive safe during the reinstallation process!

---

## 🆘 Emergency Contacts / Resources

- Apple Support: 1-800-MY-APPLE
- [macOS Recovery Mode Guide](https://support.apple.com/guide/mac-help/macos-recovery-mchl46d531d6)
- Your IT department (if applicable)
- This checklist location: `~/.local/bin/mac_assessment/PRE_REINSTALL_CHECKLIST.md`

---

## 📅 Completion Record

- **Date Started**: _______________
- **Date Completed**: _______________
- **Backup Location**: _______________
- **Backup Size**: _______________
- **Notes**: _______________________
