# Mac Data Assessment Tool

## 📋 Overview

A comprehensive READ-ONLY assessment tool designed to inventory **all** your Mac data before reinstallation. This tool is specifically designed for developers and ensures you won't lose any critical files, configurations, or credentials.

**This script will NOT delete or modify any files** - it only reads and generates reports.

## 🎯 What Gets Assessed

### System & Applications
- ✅ System information and disk usage
- ✅ All installed applications (including Mac App Store)
- ✅ Homebrew packages (Formulae + Casks)
- ✅ System preferences and defaults

### Development Environment
- ✅ **Git repositories** with uncommitted changes detection
- ✅ **Xcode** settings, snippets, archives, provisioning profiles
- ✅ **Apple Developer certificates** and provisioning profiles
- ✅ **VS Code** settings, extensions, keybindings
- ✅ **JetBrains IDEs** (IntelliJ, Android Studio, etc.)
- ✅ **Android SDK** and iOS Simulators
- ✅ Programming language runtimes (Node, Python, Ruby, Go, etc.)
- ✅ Package managers (npm, pip, gem, etc.)
- ✅ Version managers (nvm, rbenv, pyenv, etc.)
- ✅ Databases (PostgreSQL, MySQL, MongoDB, Redis)
- ✅ Docker containers and images
- ✅ CI/CD configuration files

### Personal Data
- ✅ **Browser profiles** (Chrome, Firefox, Safari)
- ✅ **Dotfiles** (.zshrc, .gitconfig, .ssh/, etc.)
- ✅ **SSH keys** (private and public)
- ✅ **GPG keys** and keychains
- ✅ **Sensitive files** (.env, credentials, certificates)
- ✅ **Large files** and directories (>100MB)
- ✅ **Duplicate/overlapping** backup folders

## 🚀 Quick Start

### Step 1: Download and Prepare

```bash
# Navigate to the assessment tool directory
cd ~/dotfiles/.mybin/mac_assessment

# Make the script executable
chmod +x assess_mac_data.sh
```

### Step 2: Run the Assessment

```bash
# Run the script (takes 5-15 minutes depending on your data)
./assess_mac_data.sh
```

The script will create a timestamped report directory:
```
~/mac_assessment_report_YYYYMMDD_HHMMSS/
```

### Step 3: Review the Reports

```bash
# Open the summary report first
open ~/mac_assessment_report_*/00_SUMMARY.txt

# Browse all reports
open ~/mac_assessment_report_*
```

## 📁 Report Files Generated

| File | Description |
|------|-------------|
| `00_SUMMARY.txt` | **START HERE** - Executive summary with priorities |
| `01_system_info.txt` | System specs and disk usage |
| `02_git_repositories.txt` | All git repos with status (⚠️ uncommitted changes) |
| `03_homebrew_packages.txt` | Installed Homebrew packages |
| `04_mac_app_store.txt` | Mac App Store applications |
| `05_all_applications.txt` | All installed applications |
| `06_browser_profiles.txt` | Browser data locations and sizes |
| `07_dotfiles.txt` | Important configuration files |
| `08_sensitive_files.txt` | Credentials, keys, certificates |
| `09_system_preferences.txt` | macOS system settings |
| `10_large_files.txt` | Files >100MB and largest directories |
| `11_dev_environments.txt` | Development tools and runtimes |
| `12_app_development.txt` | Xcode, IDEs, certificates, provisioning profiles |
| `13_folder_overlap.txt` | Duplicate and backup-like folders |
| `Brewfile` | Homebrew packages for easy restoration |

## 🔴 Critical Items to Backup (Don't Skip!)

### Highest Priority - Data Loss Risk
1. **Git repositories with uncommitted changes** (See `02_git_repositories.txt`)
2. **SSH private keys** (`~/.ssh/id_rsa`, `~/.ssh/id_ed25519`)
3. **GPG keys** - Export with: `gpg --export-secret-keys > gpg-backup.asc`
4. **Apple Developer certificates** (See `12_app_development.txt`)
5. **Provisioning profiles** (`~/Library/MobileDevice/Provisioning Profiles`)
6. **Keychains** (`~/Library/Keychains/`)
7. **Environment files** (`.env`, `credentials.json`, etc.)

### High Priority - Difficult to Recreate
8. **Browser profiles** - Passwords, extensions, bookmarks
9. **Xcode archives** - For App Store submissions
10. **Xcode snippets and keybindings** (`~/Library/Developer/Xcode/UserData`)
11. **VS Code settings** (`~/Library/Application Support/Code/User/`)
12. **IDE configurations** (JetBrains, Android Studio)
13. **Database dumps** - Export all local databases
14. **Dotfiles** (`.zshrc`, `.gitconfig`, etc.)

### Medium Priority - Time-Consuming to Rebuild
15. **Application lists** (Use the generated `Brewfile`)
16. **Mac App Store apps list** (See `04_mac_app_store.txt`)
17. **Development tool configurations**
18. **System preferences** (Can be manually restored)

## ⚡ Quick Backup Commands

After reviewing the reports, use these commands to backup critical data:

```bash
# Create backup directory
mkdir -p ~/Desktop/mac_backup_$(date +%Y%m%d)
cd ~/Desktop/mac_backup_$(date +%Y%m%d)

# Backup SSH keys
cp -r ~/.ssh ./ssh_backup

# Export GPG keys
gpg --export-secret-keys > gpg_private_keys.asc
gpg --export > gpg_public_keys.asc

# Backup dotfiles
cp ~/.zshrc ./zshrc
cp ~/.gitconfig ./gitconfig
cp -r ~/.config ./config_backup

# Backup Chrome profile
rsync -av ~/Library/Application\ Support/Google/Chrome/Default ./chrome_default_profile

# Backup Xcode UserData (snippets, keybindings, themes)
rsync -av ~/Library/Developer/Xcode/UserData ./xcode_userdata

# Backup provisioning profiles
rsync -av ~/Library/MobileDevice/Provisioning\ Profiles ./provisioning_profiles

# Backup VS Code settings
rsync -av ~/Library/Application\ Support/Code/User ./vscode_settings
code --list-extensions > vscode_extensions.txt

# Copy the Brewfile for easy restoration
cp ~/mac_assessment_report_*/Brewfile ./Brewfile

# Backup keychains
cp -r ~/Library/Keychains ./keychains_backup
```

## 🔄 After Reinstallation - Restoration Guide

### 1. Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Restore Homebrew Packages
```bash
# Copy your Brewfile to the new system
brew bundle install --file=~/Desktop/mac_backup_YYYYMMDD/Brewfile
```

### 3. Restore SSH Keys
```bash
cp -r ~/Desktop/mac_backup_YYYYMMDD/ssh_backup ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

### 4. Restore GPG Keys
```bash
gpg --import ~/Desktop/mac_backup_YYYYMMDD/gpg_private_keys.asc
gpg --import ~/Desktop/mac_backup_YYYYMMDD/gpg_public_keys.asc
```

### 5. Restore Dotfiles
```bash
cp ~/Desktop/mac_backup_YYYYMMDD/zshrc ~/.zshrc
cp ~/Desktop/mac_backup_YYYYMMDD/gitconfig ~/.gitconfig
source ~/.zshrc
```

### 6. Restore VS Code Settings
```bash
rsync -av ~/Desktop/mac_backup_YYYYMMDD/vscode_settings/ ~/Library/Application\ Support/Code/User/

# Restore extensions
cat ~/Desktop/mac_backup_YYYYMMDD/vscode_extensions.txt | xargs -n 1 code --install-extension
```

### 7. Restore Xcode Data
```bash
rsync -av ~/Desktop/mac_backup_YYYYMMDD/xcode_userdata/ ~/Library/Developer/Xcode/UserData/
rsync -av ~/Desktop/mac_backup_YYYYMMDD/provisioning_profiles/ ~/Library/MobileDevice/Provisioning\ Profiles/
```

### 8. Import Keychain (Optional)
```bash
# Note: Only import if you understand the security implications
# You may need to re-enter passwords
```

## 📝 Pre-Reinstall Checklist

Use this checklist before wiping your Mac:

- [ ] Run the assessment script and review ALL reports
- [ ] Commit and push all git repositories (check `02_git_repositories.txt`)
- [ ] Export all SSH keys
- [ ] Export all GPG keys
- [ ] Backup browser profiles (passwords, extensions)
- [ ] Export Apple Developer certificates from Keychain
- [ ] Backup Xcode archives and provisioning profiles
- [ ] Export all database dumps (PostgreSQL, MySQL, etc.)
- [ ] Backup VS Code and IDE settings
- [ ] Copy all `.env` files and credentials
- [ ] Document all running services and their configurations
- [ ] Take screenshots of important System Preferences
- [ ] Verify all backups are on external drive or cloud storage
- [ ] Create a Brewfile from the assessment report
- [ ] Write down all Mac App Store apps to reinstall
- [ ] Backup any files in Downloads/Desktop/Documents
- [ ] Export any local-only data (notes, bookmarks, etc.)
- [ ] Sign out of all applications (especially licensed software)

## 🛡️ Security & Privacy

- **READ-ONLY**: This script never modifies, deletes, or moves files
- **Local Only**: All reports stay on your Mac, nothing is uploaded
- **Sensitive Data**: Reports may contain file paths and names of sensitive files
- **Report Sharing**: Review reports before sharing - they may contain private info

## 🐛 Troubleshooting

### Script takes too long
The script scans your entire home directory. This is normal for:
- Large file detection (10+ minutes)
- Git repository scanning (5+ minutes)
- Folder overlap analysis (5+ minutes)

### "Permission denied" errors
Some system directories may be inaccessible. This is normal and won't affect the overall assessment.

### Missing data in reports
If the script can't find certain tools (like `mas` for App Store apps), it will note this in the report and suggest installation commands.

## 📚 Additional Resources

- [Apple's official backup guide](https://support.apple.com/mac-backup)
- [Homebrew documentation](https://docs.brew.sh/)
- [VS Code settings sync](https://code.visualstudio.com/docs/editor/settings-sync)

## 🤝 Need Help?

1. Review the `00_SUMMARY.txt` report first
2. Check each numbered report for specific categories
3. Look for ⚠️ warnings in reports - these need immediate attention
4. For git repos with uncommitted changes, see `02_git_repositories.txt`

## 📬 Sharing Reports

To share reports for analysis:

```bash
# Create a shareable archive (safe - no sensitive file contents)
cd ~
tar -czf mac_assessment_reports.tar.gz mac_assessment_report_*/

# Share the tar.gz file
```

**Note**: Reports contain file paths and names but NOT file contents. Review before sharing.

---

**Remember**: The goal is to make sure you can sleep well after reinstalling your Mac, knowing that no important data was lost! 🛌💤
