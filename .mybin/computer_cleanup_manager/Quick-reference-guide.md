# Quick Reference Guide

## 🎯 Common Tasks

### Initial Setup

```bash
# 1. Install prerequisites
brew install git gh jq gpg  # macOS
# or
sudo apt install git gh jq gpg  # Linux

# 2. Authenticate with GitHub
gh auth login

# 3. Run installer
./install.sh

# 4. Configure
nano ~/.cleanup.config
```

### Daily Workflows

#### Clean Up Your Dev Folder

```bash
# Preview first
cleanup-manager --dry-run ~/dev

# Do it for real
cleanup-manager ~/dev

# Resume if interrupted
cleanup-manager --resume ~/dev
```

#### Quick Dotfiles Sync

```bash
# Sync changes
version-dotfiles --sync

# Or: add new file and sync
version-dotfiles --add ~/.config/new-app
version-dotfiles --sync
```

#### Process Specific Folders

```bash
# Skip some folders
cleanup-manager --skip node_modules --skip .venv ~/dev

# Use specific owner
cleanup-manager --owner BrightSoftwares ~/dev
```

## 📋 Cheat Sheet

### Cleanup Manager Options

| Option | Description | Example |
|--------|-------------|---------|
| `--dry-run` | Preview without changes | `cleanup-manager --dry-run ~/dev` |
| `--resume` | Resume previous session | `cleanup-manager --resume ~/dev` |
| `--skip <folder>` | Skip specific folder | `cleanup-manager --skip temp ~/dev` |
| `--owner <name>` | Set GitHub owner | `cleanup-manager --owner myorg ~/dev` |
| `--verbose` | Detailed output | `cleanup-manager --verbose ~/dev` |
| `--analyze-only` | Just categorize | `cleanup-manager --analyze-only ~/dev` |
| `--batch-size <n>` | Process n at a time | `cleanup-manager --batch-size 5 ~/dev` |

### Dotfiles Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `--init` | Initialize repo | `version-dotfiles --init` |
| `--add <path>` | Track file/folder | `version-dotfiles --add ~/.vimrc` |
| `--sync` | Commit and push | `version-dotfiles --sync` |
| `--list` | Show tracked items | `version-dotfiles --list` |
| `--restore` | Restore from repo | `version-dotfiles --restore` |
| `--untrack <path>` | Stop tracking | `version-dotfiles --untrack ~/.bashrc` |

### File Locations

| Path | Contents |
|------|----------|
| `~/.cleanup.config` | Your configuration |
| `~/.cleanup_state/` | Progress tracking |
| `~/.cleanup_backups/` | Safety backups |
| `~/dev_completed/` | Processed folders |
| `~/dotfiles/` | Your dotfiles repo |
| `logs/` | Execution logs |

## 🔧 Configuration Snippets

### Minimal Config

```bash
# ~/.cleanup.config
DEFAULT_GITHUB_OWNERS="myusername"
MY_GITHUB_ACCOUNTS=("myusername")
COMPLETED_FOLDER="$HOME/dev_completed"
```

### Production Config

```bash
# ~/.cleanup.config
DEFAULT_GITHUB_OWNERS="myuser,myorg,myorg2"
MY_GITHUB_ACCOUNTS=("myuser" "myorg" "myorg2")
DEFAULT_OWNER="myorg"  # Skip selection prompt
COMPLETED_FOLDER="$HOME/dev_completed"
BACKUP_DIR="$HOME/.cleanup_backups"
DOTFILES_REPO="$HOME/dotfiles"
ALWAYS_BACKUP=true
REQUIRE_CONFIRMATION=true
LOG_LEVEL=1
```

### Security-Focused Config

```bash
# ~/.cleanup.config
ALWAYS_BACKUP=true
REQUIRE_CONFIRMATION=true
MAX_FILE_SIZE_MB=50
SENSITIVE_PATTERNS=(
    ".env*"
    "*secret*"
    "*credentials*"
    "*.pem"
    "*.key"
    "api_keys*"
)
```

## 🎬 Example Workflows

### Workflow 1: New Machine Setup

```bash
# On old machine - backup dotfiles
version-dotfiles --init
version-dotfiles --add ~/.bashrc
version-dotfiles --add ~/.zshrc
version-dotfiles --add ~/.config
version-dotfiles --sync

# On new machine - restore
git clone https://github.com/yourusername/dotfiles
cd dotfiles
version-dotfiles --restore
```

### Workflow 2: Clean Project Folders

```bash
# Step 1: Analyze what you have
cleanup-manager --analyze-only ~/dev

# Step 2: Review categories
cat ~/.cleanup_state/categories_*.txt

# Step 3: Preview changes
cleanup-manager --dry-run ~/dev

# Step 4: Execute
cleanup-manager ~/dev

# Step 5: Review report
cat ~/.cleanup_state/report_*.txt
```

### Workflow 3: Batch Fork External Repos

```bash
# Run cleanup on external repos
cleanup-manager --owner myorg ~/external_repos

# It will:
# 1. Detect they're external
# 2. Prompt to fork
# 3. Update remotes
# 4. Push changes to your fork
```

### Workflow 4: Organize Downloads

```bash
# Move items from Downloads to dev
mv ~/Downloads/project1 ~/dev/

# Process with cleanup tool
cleanup-manager ~/dev

# project1 will be:
# 1. Analyzed
# 2. Repo created if needed
# 3. Changes committed
# 4. Pushed to GitHub
```

## 🐛 Quick Fixes

### Fix: Script Not Executable

```bash
chmod +x cleanup_manager.sh version_dotfiles.sh
chmod +x lib/*.sh
```

### Fix: Can't Find Commands

```bash
# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Fix: GitHub Auth Issues

```bash
gh auth logout
gh auth login
# Choose: GitHub.com, HTTPS, Login with browser
```

### Fix: GPG Issues

```bash
# Test GPG
gpg --version

# Create key if needed
gpg --full-generate-key

# List keys
gpg --list-keys
```

### Fix: Reset Everything

```bash
# Clean state
rm -rf ~/.cleanup_state/*

# Remove processed folders from completed
# (move back to dev if needed)

# Start fresh
cleanup-manager ~/dev
```

## 📊 Reading Reports

### Summary Report Format

```
======================================
Mac Cleanup Summary Report
Generated: 2024-10-08 14:30:00
======================================

Statistics:
  Total folders processed: 25
  Completed: 18
  Skipped: 5
  Failed: 2
  Deleted: 0

Category Breakdown:
-----------------------------------
  my_repo_with_changes: 12
  external_to_fork: 6
  not_a_repo: 4
  my_repo_clean: 3

Detailed Folder List:
-----------------------------------
[completed] project1 (my_repo_with_changes)
[completed] project2 (external_to_fork)
[skipped] temp (not_a_repo)
...
```

### CSV Analysis

```bash
# Open in Excel/Numbers
open ~/.cleanup_state/report_*.csv

# Or analyze with command line
cat ~/.cleanup_state/report_*.csv | column -t -s,

# Count by status
awk -F, 'NR>1 {print $2}' report.csv | sort | uniq -c

# Count by category
awk -F, 'NR>1 {print $3}' report.csv | sort | uniq -c
```

## 🔍 Debugging

### Enable Debug Mode

```bash
# Method 1: Environment variable
VERBOSE=true cleanup-manager ~/dev

# Method 2: Configuration
echo "VERBOSE=true" >> ~/.cleanup.config
cleanup-manager ~/dev

# Method 3: Command line
cleanup-manager --verbose ~/dev
```

### Check Logs

```bash
# View latest log
tail -f logs/cleanup_*.log

# Search for errors
grep ERROR logs/cleanup_*.log

# Filter by folder
grep "project1" logs/cleanup_*.log
```

### Manual State Inspection

```bash
# View state file
jq . ~/.cleanup_state/state_*.json

# Check categories
cat ~/.cleanup_state/categories_*.txt

# View checkpoint
cat ~/.cleanup_state/checkpoint_*.txt
```

## 💡 Pro Tips

1. **Always Dry Run First**: `cleanup-manager --dry-run ~/dev`

2. **Use Specific Owner**: `cleanup-manager --owner myorg ~/dev` (skips prompts)

3. **Batch Similar Tasks**: Process all external repos, then all your repos

4. **Keep Backups**: Never disable `ALWAYS_BACKUP=true`

5. **Review Before Pushing**: Check `git status` before confirming pushes

6. **Use Categories**: Analyze first, then process by category

7. **Regular Dotfiles Syncs**: `version-dotfiles --sync` weekly

8. **Monitor Disk Space**: Check `dev_completed/` size periodically

9. **Clean Old Logs**: `find logs/ -mtime +30 -delete`

10. **Document Custom Patterns**: Keep notes on your sensitive file patterns

## 🚀 Keyboard Shortcuts

When prompted during execution:

- `y` or `Y` - Yes
- `n` or `N` - No
- `c` or `C` - Continue
- `s` or `S` - Skip
- `a` or `A` - Abort
- `Ctrl+C` - Stop (state is saved)

## 📱 Integration Ideas

### With Alfred/Raycast

```bash
# Create Alfred workflow
cleanup-manager --dry-run ~/dev | open -f
```

### With Cron

```bash
# Weekly dotfiles sync
0 0 * * 0 cd ~/dotfiles && version-dotfiles --sync
```

### With Git Hooks

```bash
# .git/hooks/post-commit
version-dotfiles --sync
```

---

**Keep this guide handy for quick reference!**