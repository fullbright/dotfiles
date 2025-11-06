#!/bin/bash
#
# Configuration file for Mac Assessment Tool
# Edit this file to customize where the script searches for your data
#

# Additional directories to search for Git repositories
# Add any directories where you keep code/projects
CUSTOM_GIT_SEARCH_DIRS=(
    # Add your custom directories here, one per line
    # Examples:
    # "/Volumes/ExternalDrive/Projects"
    # "${HOME}/Work"
    # "${HOME}/Clients"
    # "${HOME}/OldProjects"

    # Uncomment and add your directories below:
    # "${HOME}/path/to/your/repos"
)

# Additional directories to search for office files
CUSTOM_OFFICE_SEARCH_DIRS=(
    # Add directories containing office files (PDF, Word, Excel, etc.)
    # Examples:
    # "${HOME}/Dropbox"
    # "${HOME}/OneDrive"
    # "/Volumes/ExternalDrive/Documents"

    # Uncomment and add your directories below:
    # "${HOME}/path/to/your/documents"
)

# FTP Configuration (for remote backup)
FTP_ENABLED=false           # Set to true to enable FTP upload
FTP_HOST=""                 # FTP server hostname or IP
FTP_PORT=21                 # FTP port (default: 21)
FTP_USER=""                 # FTP username
FTP_PASS=""                 # FTP password (WARNING: stored in plain text!)
FTP_REMOTE_DIR=""           # Remote directory to upload to

# Encryption Settings
ENCRYPT_BACKUP=false        # Set to true to encrypt backup before upload
GPG_RECIPIENT=""            # GPG key ID or email for encryption
ENCRYPTION_PASSWORD=""      # Or use password-based encryption (less secure)

# Export variables so they're available to the main script
export CUSTOM_GIT_SEARCH_DIRS
export CUSTOM_OFFICE_SEARCH_DIRS
export FTP_ENABLED
export FTP_HOST
export FTP_PORT
export FTP_USER
export FTP_PASS
export FTP_REMOTE_DIR
export ENCRYPT_BACKUP
export GPG_RECIPIENT
export ENCRYPTION_PASSWORD
