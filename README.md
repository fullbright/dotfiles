# Dotfiles

Cross-platform dotfiles management using the git bare repository method.

**Supported Platforms:** macOS, Linux, Windows (WSL/Git Bash)

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/fullbright/dotfiles/main/install.sh | bash
```

Or manually:

```bash
git clone --bare https://github.com/fullbright/dotfiles.git $HOME/.dotfiles
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

## Usage

After installation, use the `dotfiles` command instead of `git`:

```bash
dotfiles status              # Check status of your dotfiles
dotfiles add .vimrc          # Stage a file
dotfiles commit -m "Update"  # Commit changes
dotfiles push                # Push to remote
dotfiles pull                # Pull updates
```

## Repository Structure

```
~/
├── .zshrc                    # Zsh configuration
├── .vimrc                    # Vim configuration
├── .gitconfig                # Git configuration
├── .config/
│   ├── macos/                # macOS-specific configs
│   │   └── corey_schafer_reference/  # Reference dotfiles
│   ├── linux/                # Linux-specific configs
│   │   └── install_*.sh      # Linux setup scripts
│   └── windows/              # Windows-specific configs
├── .local/bin/               # Personal scripts and tools
├── .oh-my-zsh-custom/        # Oh-My-Zsh customizations
└── install.sh                # Cross-platform installer
```

## Encrypted Files

Sensitive files are GPG-encrypted. To decrypt:

```bash
gpg --decrypt --output file file.gpg
```

For tar.gz.gpg files:

```bash
gpg --decrypt --output file.tar.gz file.tar.gz.gpg
tar -xzf file.tar.gz
```

## Platform-Specific Setup

### macOS

The installer can run Homebrew setup from the Corey Schafer reference dotfiles:

```bash
~/.config/macos/corey_schafer_reference/brew.sh
```

### Linux

Install laptop tools:

```bash
~/.config/linux/install_laptop_tools.sh
```

### Windows

The installer supports:
- **winget** (Windows 11+ built-in)
- **chocolatey** (https://chocolatey.org)
- **scoop** (https://scoop.sh)

## Security

This repo uses pre-commit hooks to prevent committing sensitive data:

```bash
pip install pre-commit
pre-commit install
```

See `.pre-commit-config.yaml` for configuration.

## Adding New Dotfiles

```bash
# Add a file from your home directory
dotfiles add ~/.newconfig

# Commit and push
dotfiles commit -m "Add newconfig"
dotfiles push
```

## Syncing Changes

```bash
# Pull latest changes
dotfiles pull

# If conflicts exist, backup and resolve
dotfiles stash
dotfiles pull
dotfiles stash pop
```

## Credits

- Git bare repository method: [Atlassian Tutorial](https://www.atlassian.com/git/tutorials/dotfiles)
- macOS reference: Corey Schafer's dotfiles
- Linux configs: xfce-laptop-config

## License

MIT License - See individual files for specific licenses.
