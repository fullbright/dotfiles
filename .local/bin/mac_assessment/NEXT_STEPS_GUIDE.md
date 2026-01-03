# 🎯 NEXT STEPS - After Running Assessment

## Your Current Situation

You've run the assessment and discovered:
- ✅ Assessment completed
- ⚠️ Some repositories not found (in other folders)
- ⚠️ Office files not assessed
- ⚠️ Duplicated files and overlapping folders
- ❓ Want to encrypt and FTP data before reinstall

---

## STEP 1: Run Enhanced Assessment (15 minutes)

The enhanced script will ask you for custom directories and scan for office files.

```bash
cd ~/.local/bin/mac_assessment

# Make it executable
chmod +x assess_mac_data_enhanced.sh

# Run it - it will ask you questions
./assess_mac_data_enhanced.sh
```

**What it will ask:**
1. "Do you have repositories in other locations?" → Answer **YES**
2. Enter each directory where you have code (one per line)
3. "Do you want to search for office files?" → Answer **YES**
4. Enter each directory with documents

**Example:**
```
Directory path: /Volumes/ExternalDrive/OldProjects
Directory path: ~/Clients
Directory path: ~/Backup/Code
Directory path: [press ENTER when done]
```

---

## STEP 2: Handle Duplicated Files (30-60 minutes)

### Option A: Manual Review (Recommended for important files)

```bash
# Review the duplicate analysis
cat ~/mac_assessment_report_*/15_duplicates_enhanced.txt

# For each duplicate, compare:
diff /path/to/file1.pdf /path/to/file2.pdf

# Or for folders:
diff -r /path/to/folder1 /path/to/folder2
```

**Decision tree:**
- Same content? → Keep ONE, delete others
- Different content? → Rename to include date/version, keep both
- Backup folders? → Archive to external drive, delete from Mac

### Option B: Automated Deduplication (Faster, use carefully)

```bash
# Install fdupes via Homebrew
brew install fdupes

# Find exact duplicates in Documents
fdupes -r ~/Documents > ~/Desktop/duplicates_list.txt

# Review the list
cat ~/Desktop/duplicates_list.txt

# Delete duplicates interactively (keeps one copy)
fdupes -r -d ~/Documents
```

⚠️ **WARNING**: Review carefully before deleting!

### Handling Overlapping Backup Folders

You mentioned overlapping folders. Here's how to consolidate:

```bash
# Example: You have multiple backup folders
# ~/Documents/Backup_2023
# ~/Documents/Backup_2024
# ~/Desktop/Old_Backup

# Strategy 1: Merge into one location
mkdir -p ~/Desktop/CONSOLIDATED_BACKUP
rsync -av --ignore-existing ~/Documents/Backup_2023/ ~/Desktop/CONSOLIDATED_BACKUP/
rsync -av --ignore-existing ~/Documents/Backup_2024/ ~/Desktop/CONSOLIDATED_BACKUP/
rsync -av --ignore-existing ~/Desktop/Old_Backup/ ~/Desktop/CONSOLIDATED_BACKUP/

# Strategy 2: Find unique files in each
comm -23 \
  <(find ~/Documents/Backup_2023 -type f -exec basename {} \; | sort) \
  <(find ~/Documents/Backup_2024 -type f -exec basename {} \; | sort)

# Strategy 3: Archive old backups
tar -czf ~/Desktop/old_backups_archive.tar.gz \
  ~/Documents/Backup_2023 \
  ~/Documents/Backup_2024
```

---

## STEP 3: Configure Encryption & FTP (15 minutes)

Edit the config file:

```bash
cd ~/.local/bin/mac_assessment
nano config.sh
```

### For Encryption Only (No FTP):

```bash
# Enable encryption
ENCRYPT_BACKUP=true

# Option 1: Use GPG key (more secure)
GPG_RECIPIENT="your@email.com"  # Your GPG key email

# Option 2: Use password (simpler)
ENCRYPTION_PASSWORD="your-strong-password-here"
```

### For Encryption + FTP Upload:

```bash
# Enable encryption
ENCRYPT_BACKUP=true
ENCRYPTION_PASSWORD="your-strong-password-here"

# Enable FTP
FTP_ENABLED=true
FTP_HOST="ftp.yourserver.com"
FTP_PORT=21
FTP_USER="your_username"
FTP_PASS="your_password"
FTP_REMOTE_DIR="/backups/mac"
```

### Test FTP Connection First:

```bash
# Test with lftp
brew install lftp

lftp -u username,password ftp.yourserver.com
# If connected:
ls
cd /backups
mkdir mac
bye
```

---

## STEP 4: Create Complete Backup (2-4 hours)

Now that duplicates are handled and config is set:

```bash
cd ~/Desktop/mac_backup_YYYYMMDD

# Check the size
du -sh .
```

### Backup to External Drive:

```bash
# Connect external drive, then:
rsync -av --progress ~/Desktop/mac_backup_YYYYMMDD /Volumes/YOUR_DRIVE/

# Verify it copied
ls -lh /Volumes/YOUR_DRIVE/mac_backup_YYYYMMDD
```

### Encrypt the Backup:

```bash
cd ~/Desktop

# Create archive
tar -czf mac_backup_YYYYMMDD.tar.gz mac_backup_YYYYMMDD

# Encrypt with GPG
gpg --symmetric --cipher-algo AES256 mac_backup_YYYYMMDD.tar.gz

# This creates: mac_backup_YYYYMMDD.tar.gz.gpg
# Delete unencrypted: rm mac_backup_YYYYMMDD.tar.gz
```

### Upload to FTP:

```bash
# Using lftp (recommended)
lftp -u username,password ftp.yourserver.com <<EOF
cd /backups/mac
put mac_backup_YYYYMMDD.tar.gz.gpg
bye
EOF

# OR using curl
curl -T mac_backup_YYYYMMDD.tar.gz.gpg \
  -u username:password \
  ftp://ftp.yourserver.com/backups/mac/
```

---

## STEP 5: Verify Everything (30 minutes)

### Checklist:

- [ ] Enhanced assessment ran successfully
- [ ] All git repos found (check report)
- [ ] All office files found (check 14_office_files.txt)
- [ ] Duplicates identified and handled
- [ ] Backup created on external drive
- [ ] Backup encrypted (if using encryption)
- [ ] Backup uploaded to FTP (if using FTP)
- [ ] Test: Can you decrypt the backup?

### Test Decryption:

```bash
# Copy encrypted file to test directory
cp mac_backup_YYYYMMDD.tar.gz.gpg /tmp/test_decrypt.tar.gz.gpg

# Decrypt
gpg --decrypt /tmp/test_decrypt.tar.gz.gpg > /tmp/test.tar.gz

# Extract to verify
cd /tmp
tar -xzf test.tar.gz

# Check contents
ls -la mac_backup_YYYYMMDD

# Clean up
rm -rf /tmp/test* /tmp/mac_backup_*
```

---

## STEP 6: Handle Office Files Specifically

After running the enhanced assessment:

```bash
# Review office files report
cat ~/mac_assessment_report_*/14_office_files.txt

# Copy all office files to backup
mkdir -p ~/Desktop/mac_backup_YYYYMMDD/office_files

# Copy PDFs
find ~/Documents ~/Desktop -name "*.pdf" -exec cp {} ~/Desktop/mac_backup_YYYYMMDD/office_files/ \;

# Copy Word docs
find ~/Documents ~/Desktop -name "*.doc*" -exec cp {} ~/Desktop/mac_backup_YYYYMMDD/office_files/ \;

# Copy Excel
find ~/Documents ~/Desktop -name "*.xls*" -exec cp {} ~/Desktop/mac_backup_YYYYMMDD/office_files/ \;

# Copy PowerPoint
find ~/Documents ~/Desktop -name "*.ppt*" -exec cp {} ~/Desktop/mac_backup_YYYYMMDD/office_files/ \;
```

**Better approach - preserve directory structure:**

```bash
# Backup with structure
rsync -av --include="*/" \
  --include="*.pdf" \
  --include="*.doc" \
  --include="*.docx" \
  --include="*.xls" \
  --include="*.xlsx" \
  --include="*.ppt" \
  --include="*.pptx" \
  --exclude="*" \
  ~/Documents/ ~/Desktop/mac_backup_YYYYMMDD/office_files/
```

---

## STEP 7: Final Pre-Reinstall Checklist

Before wiping your Mac:

### Critical Items:
- [ ] All git repos have uncommitted changes pushed
- [ ] All office files backed up (check 14_office_files.txt)
- [ ] Backup on **TWO** locations (external drive + FTP/cloud)
- [ ] Backup encrypted with password you remember
- [ ] Test decrypt worked successfully
- [ ] All duplicates resolved (or archived)
- [ ] SSH keys backed up (~/Desktop/mac_backup_YYYYMMDD/ssh_backup)
- [ ] GPG keys exported
- [ ] Browser profiles backed up

### Verify Backup Size:

```bash
# Check backup size
du -sh ~/Desktop/mac_backup_YYYYMMDD

# Check external drive copy
du -sh /Volumes/YOUR_DRIVE/mac_backup_YYYYMMDD

# They should match
```

---

## STEP 8: After Reinstallation

Follow the `POST_INSTALL_GUIDE.md` but with these additions:

### 1. Retrieve Encrypted Backup:

```bash
# Download from FTP
lftp -u username,password ftp.yourserver.com <<EOF
cd /backups/mac
get mac_backup_YYYYMMDD.tar.gz.gpg
bye
EOF

# Or copy from external drive
cp /Volumes/YOUR_DRIVE/mac_backup_YYYYMMDD.tar.gz.gpg ~/Desktop/
```

### 2. Decrypt:

```bash
cd ~/Desktop
gpg --decrypt mac_backup_YYYYMMDD.tar.gz.gpg > mac_backup_YYYYMMDD.tar.gz
tar -xzf mac_backup_YYYYMMDD.tar.gz
```

### 3. Restore:

Follow `POST_INSTALL_GUIDE.md` from Phase 3 onwards.

---

## Summary Commands Quick Reference

```bash
# 1. Run enhanced assessment with custom dirs
./assess_mac_data_enhanced.sh

# 2. Find and handle duplicates
fdupes -r ~/Documents > duplicates.txt

# 3. Encrypt backup
tar -czf backup.tar.gz mac_backup_YYYYMMDD
gpg --symmetric --cipher-algo AES256 backup.tar.gz

# 4. Upload to FTP
lftp -u user,pass ftp.server.com -e "cd /path; put backup.tar.gz.gpg; bye"

# 5. Test decrypt
gpg --decrypt backup.tar.gz.gpg > test.tar.gz

# 6. After reinstall - download and decrypt
lftp -u user,pass ftp.server.com -e "cd /path; get backup.tar.gz.gpg; bye"
gpg --decrypt backup.tar.gz.gpg > backup.tar.gz
tar -xzf backup.tar.gz
```

---

## Troubleshooting

### "FTP upload fails"
```bash
# Check connection
ping ftp.yourserver.com

# Test credentials
lftp -u username,password ftp.yourserver.com -e "ls; bye"

# Check FTP port is open
nc -zv ftp.yourserver.com 21
```

### "Encryption takes too long"
```bash
# Use faster compression
tar -czf backup.tar.gz --use-compress-program=pigz mac_backup_YYYYMMDD

# Or skip compression for encrypted files
tar -cf backup.tar mac_backup_YYYYMMDD
gpg --symmetric backup.tar
```

### "Can't find all my files"
```bash
# Search entire home directory (slower)
find ~ -name "*.pdf" -o -name "*.docx" > all_office_files.txt

# Review and copy
cat all_office_files.txt
```

---

## ⚠️ Important Reminders

1. **Test your backup** before reinstalling
2. **Keep 2 copies** - external drive + cloud/FTP
3. **Remember your encryption password**
4. **Don't delete Mac data** until new Mac is fully working
5. **Export browser bookmarks** separately (as backup)

---

## 📞 Need Help?

- **Stuck with duplicates?** Use `diff -r folder1 folder2` to compare
- **FTP not working?** Try SFTP instead (more secure)
- **Too much data?** Prioritize: Code > Credentials > Documents > Everything else

**You're doing great! Take it step by step.** 🎯
