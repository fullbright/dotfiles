<#
.SYNOPSIS
Synchronizes a Git repository with advanced conflict resolution and cleanup.

.DESCRIPTION
This script:
1. Checks for local changes and commits them
2. Fetches remote changes
3. Handles merges or conflicts by either:
   - Successfully merging and pushing
   - Creating a conflict branch when merge fails
4. Cleans up merged orphan branches
5. Uses dynamic default branch detection

IMPROVEMENTS OVER ORIGINAL:
- Added robust error handling and output capture
- Improved default branch detection using modern git commands
- Added automatic conflict branch pruning
- Enhanced output formatting
- Added repository validation and branch existence checks
- Implemented retry logic for push operations
- Added verbose logging for diagnostics
- Optimized orphan branch cleanup
#>

param (
    [string]$RepoPath = "/opt/containerdata/hassio/"
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

function Write-Info($message) { Write-Host ">>> $message" -ForegroundColor Cyan }
function Write-Success($message) { Write-Host "[SUCCESS] $message" -ForegroundColor Green }
function Write-Warning($message) { Write-Host "[WARNING] $message" -ForegroundColor Yellow }
function Write-Error($message) { Write-Host "[ERROR] $message" -ForegroundColor Red }

<#
.SYNOPSIS
Executes a git command with full error handling
#>
function Invoke-GitCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    try {
        $output = git @Arguments 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw $output
        }
        return $output.Trim()
    }
    catch {
        Write-Error "Git command failed: git $($Arguments -join ' ')"
        Write-Error $_.Exception.Message
        exit 1
    }
}

<#
.SYNOPSIS
Checks if the repository has uncommitted changes
#>
function Test-RepositoryClean {
	$gitPorcelainOutput = (Invoke-GitCommand @("status", "--porcelain"))
	Write-Debug "Porcelain output = $gitPorcelainOutput"
    return [string]::IsNullOrEmpty($gitPorcelainOutput)
}

<#
.SYNOPSIS
Gets the repository's default branch name
#>
function Get-DefaultBranch {
    # Modern method - works for Git 2.28+ (2020)
    try {
        $branch = Invoke-GitCommand @("branch", "-rl", "*/HEAD")
        return ($branch -split '/')[-1].Trim()
    }
    catch {
        # Fallback method for older Git versions
        $remoteInfo = Invoke-GitCommand @("remote", "show", "origin")
        $branchLine = $remoteInfo | Select-String 'HEAD branch:\s*(\S+)'
        if ($branchLine) {
            return $branchLine.Matches.Groups[1].Value.Trim()
        }
        throw "Could not determine default branch."
    }
}

<#
.SYNOPSIS
Commits all local changes with a standard message
#>
function Save-LocalChanges {
    Write-Info "Committing local changes..."
    Invoke-GitCommand @("add", "--all") > $null
    Invoke-GitCommand @("commit", "-m", "Local changes committed") > $null
}

<#
.SYNOPSIS
Attempts merge and handles conflicts by creating backup branch
#>
function Merge-RemoteChanges {
    Write-Info "Attempting to merge remote changes..."
    try {
        # Attempt merge without auto-commit
        Invoke-GitCommand @("merge", "FETCH_HEAD", "--no-commit", "--no-ff") > $null
        
        Write-Success "Merge successful"
        Invoke-GitCommand @("commit", "-m", "Merged remote changes") > $null
        
        Write-Info "Pushing changes to remote..."
        Invoke-GitCommand @("push")
    }
    catch {
        Write-Warning "Merge conflicts detected. Creating rescue branch..."
        Invoke-GitCommand @("merge", "--abort") > $null
        
        $localSHA = (Invoke-GitCommand @("rev-parse", "--short", "HEAD")).Trim()
        $remoteSHA = (Invoke-GitCommand @("rev-parse", "--short", "FETCH_HEAD")).Trim()
        $branchName = "ha_sync_${localSHA}_${remoteSHA}"
        
        # Create and push conflict branch
        Invoke-GitCommand @("checkout", "-b", $branchName) > $null
        Invoke-GitCommand @("push", "-u", "origin", $branchName) > $null
        
        # Return to default branch and update
        $defaultBranch = Get-DefaultBranch
        Invoke-GitCommand @("checkout", $defaultBranch) > $null
        Invoke-GitCommand @("pull") > $null
        
        Write-Warning "Created conflict branch: $branchName"
    }
}

<#
.SYNOPSIS
Cleans up merged orphan branches
#>
function Remove-OrphanBranches {
    Write-Info "Cleaning orphan branches..."
    $defaultBranch = Get-DefaultBranch
    $orphanBranches = Invoke-GitCommand @("branch", "--list", "ha_sync_*", "--format=%(refname:short)") |
        Where-Object { $_ -match 'ha_sync_' }
    
    foreach ($branch in $orphanBranches) {
        # Check if fully merged into default branch
        $isMerged = [bool](Invoke-GitCommand @("branch", "--merged", $defaultBranch, "--list", $branch))
        
        if ($isMerged) {
            Write-Info "Deleting orphan branch: $branch"
            try {
                # Local deletion
                Invoke-GitCommand @("branch", "-d", $branch) > $null
                
                # Remote deletion with retry
                try {
                    Invoke-GitCommand @("push", "origin", "--delete", $branch) > $null
                }
                catch {
                    Write-Warning "Retrying branch deletion..."
                    Start-Sleep -Seconds 2
                    Invoke-GitCommand @("push", "origin", "--delete", $branch) > $null
                }
            }
            catch {
                Write-Warning "Could not delete $branch : $($_.Exception.Message)"
            }
        }
        else {
            Write-Info "Skipping unmerged branch: $branch"
        }
    }
}

<#
.SYNOPSIS
Main synchronization workflow
#>
function Sync-Repository {
    # Validate repository
    if (-not (Test-Path (Join-Path $RepoPath ".git") -PathType Container)) {
        Write-Error "Not a Git repository: $RepoPath"
        exit 1
    }
    
    Set-Location $RepoPath
    Write-Info "Starting synchronization in $(Get-Location)"
    
    # Ensure default branch is checked out
    $defaultBranch = Get-DefaultBranch
    Write-Info "Default branch detected: $defaultBranch"
    #Invoke-GitCommand @("checkout", $defaultBranch) > $null
    
    # Check for local changes
    if (-not (Test-RepositoryClean)) {
        Write-Warning "Uncommitted changes detected"
        Save-LocalChanges
    }
    else {
        Write-Success "Working directory clean"
    }
    
    # Fetch remote updates
    Write-Info "Fetching remote changes..."
    Invoke-GitCommand @("fetch", "origin") > $null
    
    # Check for incoming changes
    $incomingChanges = Invoke-GitCommand @("log", "HEAD..FETCH_HEAD", "--oneline")
    if (-not [string]::IsNullOrEmpty($incomingChanges)) {
        Write-Warning "Remote changes detected"
        Merge-RemoteChanges
    }
    else {
        Write-Success "No remote changes. Check if local changes to push"
        # Push local changes if any
        if (Test-RepositoryClean) {
            Write-Info "Pushing local changes..."
            Invoke-GitCommand @("push")
        }
		else {
			Write-Warning "Repository is not clean. Not pushing."
		}
    }
    
    # Cleanup branches
    Remove-OrphanBranches
    Write-Success "Synchronization completed"
}

# Main execution
try {
    Sync-Repository
}
catch {
    Write-Error "Fatal error: $($_.Exception.Message)"
    exit 1
}