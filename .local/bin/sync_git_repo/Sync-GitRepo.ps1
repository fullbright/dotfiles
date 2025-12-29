<#
.SYNOPSIS
Enterprise-grade Git repository synchronization with conflict resolution and cleanup.

.DESCRIPTION
Synchronizes a local Git repository with its remote origin, featuring:
- Automatic change detection and commit
- Intelligent merge conflict resolution with backup branches
- Automatic cleanup of merged conflict branches
- Comprehensive logging and error handling
- Dry-run mode for safe testing
- Transaction-like rollback on critical failures

.PARAMETER RepoPath
Path to the Git repository. Defaults to /opt/containerdata/hassio/

.PARAMETER DryRun
Simulates operations without making changes

.PARAMETER LogPath
Path for log file. If not specified, logs only to console

.PARAMETER CommitMessage
Custom commit message for local changes

.PARAMETER Verbose
Enables detailed diagnostic output

.EXAMPLE
.\Sync-GitRepo.ps1 -RepoPath "C:\MyRepo" -Verbose

.EXAMPLE
.\Sync-GitRepo.ps1 -DryRun -LogPath "C:\Logs\git-sync.log"

.NOTES
Version: 2.0
Requires: Git 2.28+ (for optimal default branch detection)
Author: Enhanced Script
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$RepoPath = "/opt/containerdata/hassio/",
    
    [Parameter()]
    [switch]$DryRun,
    
    [Parameter()]
    [string]$LogPath,
    
    [Parameter()]
    [string]$CommitMessage = "Auto-sync: Local changes committed at {timestamp}",
    
    [Parameter()]
    [int]$RetryAttempts = 3,
    
    [Parameter()]
    [int]$RetryDelaySeconds = 2
)

#Requires -Version 5.1

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Script-level variables
$script:LogFile = $null
$script:OriginalBranch = $null
$script:OperationStartTime = Get-Date

#region Logging Functions

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        'Info'    { Write-Host ">>> $Message" -ForegroundColor Cyan }
        'Success' { Write-Host "[OK] $Message" -ForegroundColor Green }
        'Warning' { Write-Host "[!] $Message" -ForegroundColor Yellow }
        'Error'   { Write-Host "[X] $Message" -ForegroundColor Red }
        'Debug'   { if ($VerbosePreference -eq 'Continue') { Write-Host "[DEBUG] $Message" -ForegroundColor Gray } }
    }
    
    # File output
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

function Initialize-Logging {
    if ($LogPath) {
        try {
            $logDir = Split-Path $LogPath -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            $script:LogFile = $LogPath
            Write-Log "Logging initialized: $LogPath" -Level Info
        }
        catch {
            Write-Warning "Could not initialize log file: $($_.Exception.Message)"
        }
    }
}

#endregion

#region Git Command Execution

function Invoke-GitCommand {
    <#
    .SYNOPSIS
    Executes a git command with comprehensive error handling and retry logic
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        
        [switch]$AllowFailure,
        
        [switch]$ReturnExitCode,
        
        [int]$MaxRetries = 0
    )
    
                $attempt = 0
    $maxAttempts = $MaxRetries + 1
    $lastError = $null
    
    do {
        $attempt++
        $lastError = $null
        
        try {
            $cmdString = "git $($Arguments -join ' ')"
            Write-Log "Executing: $cmdString" -Level Debug
            
            if ($DryRun -and $Arguments[0] -in @('add', 'commit', 'push', 'merge', 'branch', 'checkout')) {
                $cmdString = "git $($Arguments -join ' ')"
                Write-Log "[DRY-RUN] Would execute: $cmdString" -Level Warning
                return "[DRY-RUN MODE]"
            }
            
            # Save current ErrorActionPreference and set to Continue to capture output without throwing
            $oldErrorAction = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            
            # Execute git and capture output
            $output = & git @Arguments 2>&1
            $exitCode = $LASTEXITCODE
            
            # Restore ErrorActionPreference
            $ErrorActionPreference = $oldErrorAction
            
            if ($ReturnExitCode) {
                return $exitCode
            }
            
            # Convert output to strings
            $outputText = @()
            $stderrText = @()
            
            foreach ($item in $output) {
                if ($item -is [System.Management.Automation.ErrorRecord]) {
                    # Git writes progress info to stderr - this is normal
                    $stderrText += $item.ToString()
                } else {
                    $outputText += $item.ToString()
                }
            }
            
            $stdoutString = ($outputText -join "`n").Trim()
            $stderrString = ($stderrText -join "`n").Trim()
            
            # Log stderr as debug (it's usually just progress info)
            if ($stderrString) {
                Write-Log "Git stderr: $stderrString" -Level Debug
            }
            
            # Check exit code - this is the TRUE indicator of success/failure
            if ($exitCode -ne 0) {
                $errorMessage = if ($stderrString) { $stderrString } elseif ($stdoutString) { $stdoutString } else { "Unknown error" }
                
                if (-not $AllowFailure) {
                    throw "Git command failed (exit code: $exitCode)`n$errorMessage"
                }
                Write-Log "Git command returned non-zero exit code: $exitCode" -Level Warning
                return $null
            }
            
            # Success! Log and return stdout
            if ($stdoutString) {
                Write-Log "Command output: $stdoutString" -Level Debug
            }
            
            return $stdoutString
        }
        catch {
            $lastError = $_
            if ($attempt -lt $maxAttempts) {
                Write-Log "Attempt $attempt failed, retrying in $RetryDelaySeconds seconds..." -Level Warning
                Start-Sleep -Seconds $RetryDelaySeconds
                continue
            }
            
            if (-not $AllowFailure) {
                $cmdString = "git $($Arguments -join ' ')"
                Write-Log "Git command failed: $cmdString" -Level Error
                $errorMsg = if ($lastError.Exception.Message) { $lastError.Exception.Message } else { "Unknown error" }
                Write-Log "Error: $errorMsg" -Level Error
                throw
            }
            return $null
        }
    } while ($attempt -lt $maxAttempts)
}

#endregion

#region Repository State Functions

function Test-GitRepository {
    <#
    .SYNOPSIS
    Validates that the path is a valid Git repository
    #>
    if (-not (Test-Path (Join-Path $RepoPath ".git") -PathType Container)) {
        throw "Not a valid Git repository: $RepoPath"
    }
    
    # Check if git is available
    try {
        $gitVersion = Invoke-GitCommand @("--version")
        Write-Log "Using $gitVersion" -Level Debug
    }
    catch {
        throw "Git is not installed or not in PATH"
    }
}

function Test-RepositoryClean {
    <#
    .SYNOPSIS
    Checks if the repository has uncommitted changes
    #>
    $status = Invoke-GitCommand @("status", "--porcelain")
    $isClean = [string]::IsNullOrWhiteSpace($status)
    
    if (-not $isClean) {
        Write-Log "Uncommitted changes detected:`n$status" -Level Debug
    }
    
    return $isClean
}

function Get-DefaultBranch {
    <#
    .SYNOPSIS
    Retrieves the repository's default branch name with multiple fallback methods
    #>
    # Method 1: Modern Git (2.28+)
    try {
        $branch = Invoke-GitCommand @("symbolic-ref", "refs/remotes/origin/HEAD") -AllowFailure
        if ($branch) {
            $branchName = ($branch -replace '^refs/remotes/origin/', '').Trim()
            if ($branchName) {
                Write-Log "Default branch detected (method 1): $branchName" -Level Debug
                return $branchName
            }
        }
    }
    catch {
        Write-Log "Method 1 failed, trying alternative..." -Level Debug
    }
    
    # Method 2: Parse remote show
    try {
        $remoteInfo = Invoke-GitCommand @("remote", "show", "origin")
        if ($remoteInfo -match 'HEAD branch:\s*(\S+)') {
            $branchName = $Matches[1].Trim()
            Write-Log "Default branch detected (method 2): $branchName" -Level Debug
            return $branchName
        }
    }
    catch {
        Write-Log "Method 2 failed, trying alternative..." -Level Debug
    }
    
    # Method 3: Common defaults
    foreach ($commonBranch in @('main', 'master', 'develop')) {
        $exists = Invoke-GitCommand @("rev-parse", "--verify", "origin/$commonBranch") -AllowFailure
        if ($exists) {
            Write-Log "Default branch detected (method 3): $commonBranch" -Level Debug
            return $commonBranch
        }
    }
    
    throw "Could not determine default branch. Please ensure remote 'origin' is configured."
}

function Get-CurrentBranch {
    <#
    .SYNOPSIS
    Gets the current branch name
    #>
    $branch = Invoke-GitCommand @("rev-parse", "--abbrev-ref", "HEAD")
    return $branch.Trim()
}

function Test-BranchUpToDate {
    <#
    .SYNOPSIS
    Checks if local branch is up-to-date, ahead, behind, or diverged from remote
    #>
    param([string]$LocalRef = "HEAD", [string]$RemoteRef = "FETCH_HEAD")
    
    # Get commit counts
    $ahead = Invoke-GitCommand @("rev-list", "--count", "$RemoteRef..$LocalRef")
    $behind = Invoke-GitCommand @("rev-list", "--count", "$LocalRef..$RemoteRef")
    
    return @{
        Ahead = [int]$ahead
        Behind = [int]$behind
        IsUpToDate = ($ahead -eq 0 -and $behind -eq 0)
        IsDiverged = ($ahead -gt 0 -and $behind -gt 0)
    }
}

#endregion

#region Change Management Functions

function Save-LocalChanges {
    <#
    .SYNOPSIS
    Commits all local changes with timestamped message
    #>
    param([string]$Message = $CommitMessage)
    
    Write-Log "Staging all changes..." -Level Info
    Invoke-GitCommand @("add", "--all")
    
    $finalMessage = $Message -replace '\{timestamp\}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-Log "Committing with message: $finalMessage" -Level Info
    
    Invoke-GitCommand @("commit", "-m", $finalMessage)
    Write-Log "Local changes committed successfully" -Level Success
}

function Invoke-SafeMerge {
    <#
    .SYNOPSIS
    Attempts merge with automatic conflict resolution via backup branch
    #>
    param([string]$DefaultBranch)
    
    Write-Log "Attempting to merge remote changes..." -Level Info
    
    try {
        # Try merge without committing first
        $mergeResult = Invoke-GitCommand @("merge", "FETCH_HEAD", "--no-commit", "--no-ff") -AllowFailure
        
        # Check for conflicts
        $conflictFiles = Invoke-GitCommand @("diff", "--name-only", "--diff-filter=U")
        
        if ($conflictFiles) {
            throw "Merge conflicts detected in files:`n$conflictFiles"
        }
        
        # No conflicts, complete the merge
        Invoke-GitCommand @("commit", "-m", "Merged remote changes")
        Write-Log "Merge completed successfully" -Level Success
        
        return $true
    }
    catch {
        Write-Log "Merge conflicts encountered: $($_.Exception.Message)" -Level Warning
        
        # Abort the failed merge
        Invoke-GitCommand @("merge", "--abort") -AllowFailure
        
        # Create conflict resolution branch
        $localSHA = (Invoke-GitCommand @("rev-parse", "--short", "HEAD")).Trim()
        $remoteSHA = (Invoke-GitCommand @("rev-parse", "--short", "FETCH_HEAD")).Trim()
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $branchName = "conflict/$timestamp`_local_${localSHA}_remote_${remoteSHA}"
        
        Write-Log "Creating conflict branch: $branchName" -Level Warning
        
        # Save current state to new branch
        Invoke-GitCommand @("checkout", "-b", $branchName)
        Invoke-GitCommand @("push", "-u", "origin", $branchName)
        
        Write-Log "Your changes are preserved in branch: $branchName" -Level Warning
        
        # Return to default branch and accept remote version
        Invoke-GitCommand @("checkout", $DefaultBranch)
        Invoke-GitCommand @("reset", "--hard", "origin/$DefaultBranch")
        
        Write-Log "Reset to remote state. Please resolve conflicts in branch: $branchName" -Level Warning
        
        return $false
    }
}

function Sync-WithRemote {
    <#
    .SYNOPSIS
    Main synchronization logic
    #>
    $defaultBranch = Get-DefaultBranch
    $currentBranch = Get-CurrentBranch
    
    Write-Log "Current branch: $currentBranch | Default branch: $defaultBranch" -Level Info
    
    # Ensure we're on the default branch
    if ($currentBranch -ne $defaultBranch) {
        Write-Log "Switching to default branch: $defaultBranch" -Level Info
        Invoke-GitCommand @("checkout", $defaultBranch)
    }
    
    # Handle local changes
    if (-not (Test-RepositoryClean)) {
        Write-Log "Uncommitted changes detected" -Level Warning
        Save-LocalChanges
    }
    else {
        Write-Log "Working directory is clean" -Level Success
    }
    
    # Fetch remote updates
    Write-Log "Fetching from origin..." -Level Info
    Invoke-GitCommand @("fetch", "origin", $defaultBranch) -MaxRetries $RetryAttempts
    
    # Analyze relationship between local and remote
    $status = Test-BranchUpToDate -LocalRef "HEAD" -RemoteRef "origin/$defaultBranch"
    
    Write-Log "Branch status - Ahead: $($status.Ahead) | Behind: $($status.Behind)" -Level Debug
    
    if ($status.IsUpToDate) {
        Write-Log "Repository is up-to-date with remote" -Level Success
        return
    }
    
    if ($status.Behind -gt 0 -and $status.Ahead -eq 0) {
        # Fast-forward possible
        Write-Log "Remote has $($status.Behind) new commit(s). Fast-forwarding..." -Level Info
        Invoke-GitCommand @("merge", "--ff-only", "origin/$defaultBranch")
        Write-Log "Fast-forward merge completed" -Level Success
    }
    elseif ($status.Ahead -gt 0 -and $status.Behind -eq 0) {
        # Only local changes, push them
        Write-Log "Local has $($status.Ahead) unpushed commit(s). Pushing..." -Level Info
        Invoke-GitCommand @("push", "origin", $defaultBranch) -MaxRetries $RetryAttempts
        Write-Log "Successfully pushed local changes" -Level Success
    }
    else {
        # Diverged - need to merge
        Write-Log "Branches have diverged (local: +$($status.Ahead), remote: +$($status.Behind))" -Level Warning
        
        if (Invoke-SafeMerge -DefaultBranch $defaultBranch) {
            # Merge successful, push the result
            Write-Log "Pushing merged changes..." -Level Info
            Invoke-GitCommand @("push", "origin", $defaultBranch) -MaxRetries $RetryAttempts
            Write-Log "Merge pushed successfully" -Level Success
        }
    }
}

#endregion

#region Cleanup Functions

function Remove-MergedConflictBranches {
    <#
    .SYNOPSIS
    Cleans up conflict branches that have been merged
    #>
    Write-Log "Scanning for merged conflict branches..." -Level Info
    
    $defaultBranch = Get-DefaultBranch
    
    # Get all conflict branches (both patterns)
    $conflictBranches = @()
    $conflictBranches += Invoke-GitCommand @("branch", "--list", "ha_sync_*", "--format=%(refname:short)") -AllowFailure
    $conflictBranches += Invoke-GitCommand @("branch", "--list", "conflict/*", "--format=%(refname:short)") -AllowFailure
    $conflictBranches = $conflictBranches | Where-Object { $_ -and $_.Trim() }
    
    if (-not $conflictBranches) {
        Write-Log "No conflict branches found" -Level Info
        return
    }
    
    $deletedCount = 0
    
    foreach ($branch in $conflictBranches) {
        $branch = $branch.Trim()
        if (-not $branch) { continue }
        
        # Check if branch is fully merged
        $mergeBase = Invoke-GitCommand @("merge-base", $branch, $defaultBranch) -AllowFailure
        $branchCommit = Invoke-GitCommand @("rev-parse", $branch) -AllowFailure
        
        if ($mergeBase -eq $branchCommit) {
            Write-Log "Deleting merged branch: $branch" -Level Info
            
            try {
                # Delete local branch
                Invoke-GitCommand @("branch", "-d", $branch) -AllowFailure
                
                # Delete remote branch
                Invoke-GitCommand @("push", "origin", "--delete", $branch) -AllowFailure -MaxRetries 2
                
                $deletedCount++
                Write-Log "Deleted: $branch" -Level Success
            }
            catch {
                Write-Log "Could not delete $branch : $($_.Exception.Message)" -Level Warning
            }
        }
        else {
            Write-Log "Skipping unmerged branch: $branch" -Level Debug
        }
    }
    
    if ($deletedCount -gt 0) {
        Write-Log "Cleaned up $deletedCount merged conflict branch(es)" -Level Success
    }
}

#endregion

#region Main Execution

function Invoke-RepositorySync {
    <#
    .SYNOPSIS
    Main orchestration function
    #>
    
    try {
        # Initialize
        Initialize-Logging
        
        if ($DryRun) {
            Write-Log "=== DRY-RUN MODE - No changes will be made ===" -Level Warning
        }
        
        Write-Log "Starting Git synchronization" -Level Info
        Write-Log "Repository: $RepoPath" -Level Info
        
        # Validate repository
        Test-GitRepository
        
        # Change to repository directory
        Push-Location $RepoPath
        
        # Store original branch for rollback
        $script:OriginalBranch = Get-CurrentBranch
        
        # Execute synchronization
        Sync-WithRemote
        
        # Cleanup old branches
        Remove-MergedConflictBranches
        
        # Summary
        $duration = (Get-Date) - $script:OperationStartTime
        Write-Log "Synchronization completed in $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level Success
        
        if ($DryRun) {
            Write-Log "=== DRY-RUN COMPLETED - No actual changes were made ===" -Level Warning
        }
    }
    catch {
        Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level Error
        if ($VerbosePreference -eq 'Continue') {
            Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level Debug
        }
        
        # Attempt rollback if we changed branches
        if ($script:OriginalBranch -and $script:OriginalBranch -ne (Get-CurrentBranch)) {
            try {
                Write-Log "Attempting to restore original branch: $script:OriginalBranch" -Level Warning
                Invoke-GitCommand @("checkout", $script:OriginalBranch) -AllowFailure
            }
            catch {
                Write-Log "Could not restore original branch" -Level Error
            }
        }
        
        throw
    }
    finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
}

# Script entry point
try {
    Invoke-RepositorySync
    exit 0
}
catch {
    $errorMsg = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error occurred" }
    Write-Log "Script failed with error: $errorMsg" -Level Error
    exit 1
}

#endregion