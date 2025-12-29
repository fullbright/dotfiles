#Requires -Version 5.1

<#
.SYNOPSIS
    AWS Group Analysis Tool - Modular PowerShell Script for AWS Account Analysis

.DESCRIPTION
    This script provides modular analysis capabilities for AWS accounts with safety measures.
    Current features:
    - User Group Redundancy Analysis: Identifies groups that can be removed because their permissions are included in other groups

.PARAMETER Feature
    The analysis feature to run. Available: UserGroupAnalysis

.PARAMETER UserName
    AWS username to analyze (required for UserGroupAnalysis)

.PARAMETER AssumeRole
    AWS role ARN to assume for cross-account access

.PARAMETER AWSProfile
    AWS CLI profile to use (default: default)

.PARAMETER OutputFormat
    Output format: CSV or Excel (default: CSV)

.PARAMETER LogRetentionDays
    Number of days to retain log files (default: 90)

.PARAMETER ExactPolicyMatch
    Compare policies using exact match only (default: true)

.PARAMETER IncludeEffectivePermissions
    Analyze effective permissions considering policy combinations (default: false)

.PARAMETER IncludeManagedPolicies
    Include AWS managed policies in analysis (default: true)

.PARAMETER IncludeInlinePolicies
    Include inline policies in analysis (default: true)

.PARAMETER DryRun
    Run in dry-run mode - no actual AWS commands executed

.PARAMETER SkipConfirmation
    Skip command confirmation prompts

.EXAMPLE
    .\AWS-GroupAnalyzer.ps1 -Feature UserGroupAnalysis -UserName "john.doe" -AssumeRole "arn:aws:iam::123456789012:role/ReadOnlyRole"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("UserGroupAnalysis")]
    [string]$Feature,
    
    [Parameter(Mandatory = $false)]
    [string]$UserName,
    
    [Parameter(Mandatory = $false)]
    [string]$AssumeRole,
    
    [Parameter(Mandatory = $false)]
    [string]$AWSProfile = "default",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("CSV", "Excel")]
    [string]$OutputFormat = "CSV",
    
    [Parameter(Mandatory = $false)]
    [int]$LogRetentionDays = 90,
    
    [Parameter(Mandatory = $false)]
    [bool]$ExactPolicyMatch = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$IncludeEffectivePermissions = $false,
    
    [Parameter(Mandatory = $false)]
    [bool]$IncludeManagedPolicies = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$IncludeInlinePolicies = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfirmation
)

#region Base Framework

# Global variables
$Script:LogPath = ""
$Script:OutputPath = ""
$Script:SessionCredentials = $null
$Script:StartTime = Get-Date

# Initialize base framework
function Initialize-Framework {
    Write-Host "Initializing AWS Group Analysis Framework..." -ForegroundColor Green
    
    # Create directories
    $scriptPath = Split-Path -Parent $MyInvocation.ScriptName
	$assetsPath = "C:\myOfflineDATA\AWS-GroupAnalyzer"
    $Script:LogPath = Join-Path $assetsPath "Logs"
    $Script:OutputPath = Join-Path $assetsPath "Output"
    
    if (!(Test-Path $Script:LogPath)) { New-Item -ItemType Directory -Path $Script:LogPath -Force | Out-Null }
    if (!(Test-Path $Script:OutputPath)) { New-Item -ItemType Directory -Path $Script:OutputPath -Force | Out-Null }
    
    # Initialize logging
    Initialize-Logging
    
    # Cleanup old logs
    Cleanup-OldLogs
    
    # Validate prerequisites
    Test-Prerequisites
    
    Write-Log "Framework initialized successfully" -Level Info
}

function Initialize-Logging {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFileName = "AWS_GroupAnalysis_$timestamp.log"
    $Script:LogFile = Join-Path $Script:LogPath $logFileName
    
    Write-Log "=== AWS Group Analysis Session Started ===" -Level Info
    Write-Log "Parameters: Feature=$Feature, UserName=$UserName, AssumeRole=$AssumeRole" -Level Info
    Write-Log "Configuration: OutputFormat=$OutputFormat, ExactPolicyMatch=$ExactPolicyMatch" -Level Info
    Write-Log "DryRun Mode: $($DryRun.IsPresent)" -Level Info
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to file
    $logEntry | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8
    
    # Write to console with color coding
    switch ($Level) {
        "Info" { Write-Host $logEntry -ForegroundColor White }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error" { Write-Host $logEntry -ForegroundColor Red }
        "Debug" { Write-Host $logEntry -ForegroundColor Cyan }
    }
}

function Cleanup-OldLogs {
    Write-Log "Cleaning up logs older than $LogRetentionDays days" -Level Info
    
    $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
    $oldLogs = Get-ChildItem -Path $Script:LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($log in $oldLogs) {
        try {
            Remove-Item $log.FullName -Force
            Write-Log "Removed old log: $($log.Name)" -Level Info
        }
        catch {
            Write-Log "Failed to remove log: $($log.Name) - $($_.Exception.Message)" -Level Warning
        }
    }
}

function Test-Prerequisites {
    Write-Log "Testing prerequisites..." -Level Info
    
    # Test AWS CLI
    try {
        $awsVersion = & aws --version 2>&1
        Write-Log "AWS CLI found: $awsVersion" -Level Info
    }
    catch {
        Write-Log "AWS CLI not found. Please install AWS CLI." -Level Error
        throw "AWS CLI is required but not found"
    }
    
    # Test Excel module if Excel output requested
    if ($OutputFormat -eq "Excel") {
        if (!(Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Log "ImportExcel module not found. Installing..." -Level Warning
            try {
                Install-Module -Name ImportExcel -Force -Scope CurrentUser
                Write-Log "ImportExcel module installed successfully" -Level Info
            }
            catch {
                Write-Log "Failed to install ImportExcel module. Falling back to CSV format." -Level Warning
                $Script:OutputFormat = "CSV"
            }
        }
    }
}

function Invoke-SafeAWSCommand {
    param(
        [string]$Command,
        [string]$Description,
        [bool]$RequiresConfirmation = $true
    )
    
    Write-Log "Preparing AWS command: $Description" -Level Info
    Write-Log "Command: $Command" -Level Debug
    
    if ($DryRun) {
        Write-Host "`n[DRY RUN] Would execute: $Command" -ForegroundColor Magenta
        Write-Log "[DRY RUN] Command: $Command" -Level Info
        return @{ Success = $true; Output = "DRY RUN MODE - No actual execution"; DryRun = $true }
    }
    
    if ($RequiresConfirmation -and !$SkipConfirmation) {
        Write-Host "`nAbout to execute AWS command:" -ForegroundColor Yellow
        Write-Host "Description: $Description" -ForegroundColor Cyan
        Write-Host "Command: $Command" -ForegroundColor White
        
        do {
            $confirmation = Read-Host "`nIs this command safe to execute? (y/n/q - quit)"
            switch ($confirmation.ToLower()) {
                'y' { break }
                'q' { 
                    Write-Log "User chose to quit" -Level Info
                    exit 0 
                }
                'n' { 
                    Write-Log "User declined to execute command: $Command" -Level Warning
                    return @{ Success = $false; Output = "User declined execution"; UserDeclined = $true }
                }
            }
        } while ($confirmation.ToLower() -notin @('y', 'n', 'q'))
    }
    
    try {
        Write-Log "Executing: $Command" -Level Info
        $output = Invoke-Expression $Command 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Command executed successfully" -Level Info
            return @{ Success = $true; Output = $output }
        } else {
            Write-Log "Command failed with exit code: $LASTEXITCODE" -Level Error
            Write-Log "Error output: $output" -Level Error
            return @{ Success = $false; Output = $output; ExitCode = $LASTEXITCODE }
        }
    }
    catch {
        Write-Log "Exception during command execution: $($_.Exception.Message)" -Level Error
        return @{ Success = $false; Output = $_.Exception.Message; Exception = $true }
    }
}

function Initialize-AWSSession {
    Write-Log "Initializing AWS session..." -Level Info
    
    # Build base AWS command
    $baseCmd = "aws"
    if ($AWSProfile -ne "default") {
        $baseCmd += " --profile $AWSProfile"
    }
    
    # Test basic connectivity
    $testCmd = "$baseCmd sts get-caller-identity --profile rios-qua"
    $result = Invoke-SafeAWSCommand -Command $testCmd -Description "Test AWS connectivity" -RequiresConfirmation $false
    
    if (!$result.Success -and !$result.DryRun) {
        throw "Failed to establish AWS connectivity: $($result.Output)"
    }
    
    if (!$result.DryRun) {
        $identity = $result.Output | ConvertFrom-Json
        Write-Log "Connected as: $($identity.Arn)" -Level Info
    }
    
    # Assume role if specified
    if ($AssumeRole) {
        Write-Log "Assuming role: $AssumeRole" -Level Info
        
        $sessionName = "GroupAnalysis-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $assumeCmd = "$baseCmd sts assume-role --role-arn '$AssumeRole' --role-session-name '$sessionName'"
        
        $result = Invoke-SafeAWSCommand -Command $assumeCmd -Description "Assume specified role"
        
        if ($result.Success -and !$result.DryRun) {
            $credentials = ($result.Output | ConvertFrom-Json).Credentials
            $Script:SessionCredentials = @{
                AccessKeyId = $credentials.AccessKeyId
                SecretAccessKey = $credentials.SecretAccessKey
                SessionToken = $credentials.SessionToken
            }
            Write-Log "Role assumed successfully" -Level Info
        }
        elseif (!$result.DryRun) {
            throw "Failed to assume role: $($result.Output)"
        }
    }
    
    return $baseCmd
}

function Get-AWSCommand {
    param([string]$Service, [string]$Operation, [string]$Parameters = "")
    
    $cmd = "aws $Service $Operation"
    
    # Add session credentials if available
    if ($Script:SessionCredentials -and !$DryRun) {
        $env:AWS_ACCESS_KEY_ID = $Script:SessionCredentials.AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $Script:SessionCredentials.SecretAccessKey
        $env:AWS_SESSION_TOKEN = $Script:SessionCredentials.SessionToken
    }
    elseif ($AWSProfile -ne "default") {
        $cmd += " --profile $AWSProfile"
    }
    
    if ($Parameters) {
        $cmd += " $Parameters"
    }
    
    return $cmd
}

#endregion

#region Feature: User Group Analysis

function Invoke-UserGroupAnalysis {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName
    )
    
    Write-Log "Starting User Group Analysis for user: $UserName" -Level Info
    
    # Initialize results structure
    $analysisResults = @{
        UserName = $UserName
        Groups = @()
        RedundantGroups = @()
        Analysis = @()
        Timestamp = Get-Date
    }
    
    try {
        # Get user's groups
        $userGroups = Get-UserGroups -UserName $UserName
        if (!$userGroups -or $userGroups.Count -eq 0) {
            Write-Log "No groups found for user: $UserName" -Level Warning
            return $analysisResults
        }
        
        Write-Log "Found $($userGroups.Count) groups for user $UserName" -Level Info
        
        # Get detailed information for each group
        $groupDetails = @()
        foreach ($groupName in $userGroups) {
            Write-Log "Analyzing group: $groupName" -Level Info
            $groupDetail = Get-GroupDetails -GroupName $groupName
            if ($groupDetail) {
                $groupDetails += $groupDetail
            }
        }
        
        $analysisResults.Groups = $groupDetails
        
        # Perform redundancy analysis
        $redundantGroups = Find-RedundantGroups -GroupDetails $groupDetails
        $analysisResults.RedundantGroups = $redundantGroups
        
        # Generate detailed analysis report
        $analysisReport = Generate-AnalysisReport -GroupDetails $groupDetails -RedundantGroups $redundantGroups
        $analysisResults.Analysis = $analysisReport
        
        # Export results
        Export-Results -Results $analysisResults -Feature "UserGroupAnalysis"
        
        # Display summary
        Display-AnalysisSummary -Results $analysisResults
        
        Write-Log "User Group Analysis completed successfully" -Level Info
        return $analysisResults
        
    }
    catch {
        Write-Log "Error during User Group Analysis: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-UserGroups {
    param([string]$UserName)
    
    Write-Log "Retrieving groups for user: $UserName" -Level Info
    
    $cmd = Get-AWSCommand -Service "iam" -Operation "get-groups-for-user" -Parameters "--user-name '$UserName'"
    $result = Invoke-SafeAWSCommand -Command $cmd -Description "Get groups for user $UserName"
    
    if (!$result.Success) {
        if ($result.DryRun) {
            return @("Group1", "Group2", "Group3") # Mock data for dry run
        }
        throw "Failed to get groups for user: $($result.Output)"
    }
    
    if ($result.DryRun) {
        return @("Group1", "Group2", "Group3") # Mock data for dry run
    }
    
    $groups = ($result.Output | ConvertFrom-Json).Groups
    return $groups | ForEach-Object { $_.GroupName }
}

function Get-GroupDetails {
    param([string]$GroupName)
    
    Write-Log "Getting details for group: $GroupName" -Level Debug
    
    $groupDetail = @{
        GroupName = $GroupName
        ManagedPolicies = @()
        InlinePolicies = @()
        PolicyDocuments = @()
    }
    
    try {
        # Get attached managed policies
        if ($IncludeManagedPolicies) {
            $managedPolicies = Get-GroupManagedPolicies -GroupName $GroupName
            $groupDetail.ManagedPolicies = $managedPolicies
        }
        
        # Get inline policies
        if ($IncludeInlinePolicies) {
            $inlinePolicies = Get-GroupInlinePolicies -GroupName $GroupName
            $groupDetail.InlinePolicies = $inlinePolicies
        }
        
        # Get policy documents for analysis
        $groupDetail.PolicyDocuments = Get-PolicyDocuments -GroupDetail $groupDetail
        
        return $groupDetail
    }
    catch {
        Write-Log "Error getting details for group $GroupName`: $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Get-GroupManagedPolicies {
    param([string]$GroupName)
    
    $cmd = Get-AWSCommand -Service "iam" -Operation "list-attached-group-policies" -Parameters "--group-name '$GroupName'"
    $result = Invoke-SafeAWSCommand -Command $cmd -Description "Get managed policies for group $GroupName" -RequiresConfirmation $false
    
    if (!$result.Success) {
        if ($result.DryRun) {
            return @(@{PolicyName="ReadOnlyAccess"; PolicyArn="arn:aws:iam::aws:policy/ReadOnlyAccess"})
        }
        Write-Log "Failed to get managed policies for group $GroupName`: $($result.Output)" -Level Warning
        return @()
    }
    
    if ($result.DryRun) {
        return @(@{PolicyName="ReadOnlyAccess"; PolicyArn="arn:aws:iam::aws:policy/ReadOnlyAccess"})
    }
    
    $policies = ($result.Output | ConvertFrom-Json).AttachedPolicies
    return $policies
}

function Get-GroupInlinePolicies {
    param([string]$GroupName)
    
    # First, list inline policy names
    $cmd = Get-AWSCommand -Service "iam" -Operation "list-group-policies" -Parameters "--group-name '$GroupName'"
    $result = Invoke-SafeAWSCommand -Command $cmd -Description "List inline policies for group $GroupName" -RequiresConfirmation $false
    
    if (!$result.Success) {
        if ($result.DryRun) {
            return @("InlinePolicy1")
        }
        Write-Log "Failed to list inline policies for group $GroupName`: $($result.Output)" -Level Warning
        return @()
    }
    
    if ($result.DryRun) {
        return @("InlinePolicy1")
    }
    
    $policyNames = ($result.Output | ConvertFrom-Json).PolicyNames
    return $policyNames
}

function Get-PolicyDocuments {
    param([hashtable]$GroupDetail)
    
    $policyDocs = @()
    
    # Get managed policy documents
    foreach ($policy in $GroupDetail.ManagedPolicies) {
        $cmd = Get-AWSCommand -Service "iam" -Operation "get-policy" -Parameters "--policy-arn '$($policy.PolicyArn)'"
        $result = Invoke-SafeAWSCommand -Command $cmd -Description "Get policy details for $($policy.PolicyName)" -RequiresConfirmation $false
        
        if ($result.Success -and !$result.DryRun) {
            $policyInfo = ($result.Output | ConvertFrom-Json).Policy
            
            # Get policy version document
            $versionCmd = Get-AWSCommand -Service "iam" -Operation "get-policy-version" -Parameters "--policy-arn '$($policy.PolicyArn)' --version-id '$($policyInfo.DefaultVersionId)'"
            $versionResult = Invoke-SafeAWSCommand -Command $versionCmd -Description "Get policy version for $($policy.PolicyName)" -RequiresConfirmation $false
            
            if ($versionResult.Success) {
                $document = ($versionResult.Output | ConvertFrom-Json).PolicyVersion.Document
                $policyDocs += @{
                    Type = "Managed"
                    Name = $policy.PolicyName
                    Arn = $policy.PolicyArn
                    Document = $document
                }
            }
        }
        elseif ($result.DryRun) {
            $policyDocs += @{
                Type = "Managed"
                Name = $policy.PolicyName
                Arn = $policy.PolicyArn
                Document = "DRY_RUN_POLICY_DOCUMENT"
            }
        }
    }
    
    # Get inline policy documents
    foreach ($policyName in $GroupDetail.InlinePolicies) {
        $cmd = Get-AWSCommand -Service "iam" -Operation "get-group-policy" -Parameters "--group-name '$($GroupDetail.GroupName)' --policy-name '$policyName'"
        $result = Invoke-SafeAWSCommand -Command $cmd -Description "Get inline policy $policyName for group $($GroupDetail.GroupName)" -RequiresConfirmation $false
        
        if ($result.Success -and !$result.DryRun) {
            $document = ($result.Output | ConvertFrom-Json).PolicyDocument
            $policyDocs += @{
                Type = "Inline"
                Name = $policyName
                GroupName = $GroupDetail.GroupName
                Document = $document
            }
        }
        elseif ($result.DryRun) {
            $policyDocs += @{
                Type = "Inline"
                Name = $policyName
                GroupName = $GroupDetail.GroupName
                Document = "DRY_RUN_POLICY_DOCUMENT"
            }
        }
    }
    
    return $policyDocs
}

function Find-RedundantGroups {
    param([array]$GroupDetails)
    
    Write-Log "Analyzing groups for redundancy..." -Level Info
    $redundantGroups = @()
    
    for ($i = 0; $i -lt $GroupDetails.Count; $i++) {
        for ($j = $i + 1; $j -lt $GroupDetails.Count; $j++) {
            $group1 = $GroupDetails[$i]
            $group2 = $GroupDetails[$j]
            
            Write-Log "Comparing $($group1.GroupName) with $($group2.GroupName)" -Level Debug
            
            # Check if group1's permissions are subset of group2
            if (Test-PermissionSubset -SourceGroup $group1 -TargetGroup $group2) {
                $redundantGroups += @{
                    RedundantGroup = $group1.GroupName
                    SupersetGroup = $group2.GroupName
                    Reason = "All permissions in $($group1.GroupName) are included in $($group2.GroupName)"
                }
                Write-Log "$($group1.GroupName) is redundant - permissions included in $($group2.GroupName)" -Level Info
            }
            # Check if group2's permissions are subset of group1
            elseif (Test-PermissionSubset -SourceGroup $group2 -TargetGroup $group1) {
                $redundantGroups += @{
                    RedundantGroup = $group2.GroupName
                    SupersetGroup = $group1.GroupName
                    Reason = "All permissions in $($group2.GroupName) are included in $($group1.GroupName)"
                }
                Write-Log "$($group2.GroupName) is redundant - permissions included in $($group1.GroupName)" -Level Info
            }
        }
    }
    
    # Check for empty groups
    foreach ($group in $GroupDetails) {
        if ($group.PolicyDocuments.Count -eq 0) {
            $redundantGroups += @{
                RedundantGroup = $group.GroupName
                SupersetGroup = "N/A"
                Reason = "Group has no policies attached"
            }
            Write-Log "$($group.GroupName) is redundant - no policies attached" -Level Info
        }
    }
    
    return $redundantGroups
}

function Test-PermissionSubset {
    param(
        [hashtable]$SourceGroup,
        [hashtable]$TargetGroup
    )
    
    if ($ExactPolicyMatch) {
        return Test-ExactPolicyMatch -SourceGroup $SourceGroup -TargetGroup $TargetGroup
    } else {
        return Test-EffectivePermissions -SourceGroup $SourceGroup -TargetGroup $TargetGroup
    }
}

function Test-ExactPolicyMatch {
    param(
        [hashtable]$SourceGroup,
        [hashtable]$TargetGroup
    )
    
    # For exact matching, all policies in source must be present in target
    foreach ($sourcePolicy in $SourceGroup.PolicyDocuments) {
        $matchFound = $false
        
        foreach ($targetPolicy in $TargetGroup.PolicyDocuments) {
            if ($sourcePolicy.Type -eq "Managed" -and $targetPolicy.Type -eq "Managed") {
                if ($sourcePolicy.Arn -eq $targetPolicy.Arn) {
                    $matchFound = $true
                    break
                }
            }
            elseif ($sourcePolicy.Type -eq "Inline" -and $targetPolicy.Type -eq "Inline") {
                # For inline policies, compare the document content
                if (Compare-PolicyDocuments -Policy1 $sourcePolicy.Document -Policy2 $targetPolicy.Document) {
                    $matchFound = $true
                    break
                }
            }
        }
        
        if (!$matchFound) {
            return $false
        }
    }
    
    return $true
}

function Test-EffectivePermissions {
    param(
        [hashtable]$SourceGroup,
        [hashtable]$TargetGroup
    )
    
    # This is a simplified implementation for effective permissions
    # In a production environment, you would need a more sophisticated policy evaluation engine
    
    Write-Log "Effective permissions analysis is simplified in this implementation" -Level Warning
    
    # Extract all actions from source group policies
    $sourceActions = Get-ActionsFromPolicyDocuments -PolicyDocuments $SourceGroup.PolicyDocuments
    $targetActions = Get-ActionsFromPolicyDocuments -PolicyDocuments $TargetGroup.PolicyDocuments
    
    # Check if all source actions are covered by target actions
    foreach ($action in $sourceActions) {
        $isDirectMatch = $targetActions -contains $action
        $isWildcardMatch = Test-ActionWildcardMatch -Action $action -WildcardActions $targetActions
        
        if (-not $isDirectMatch -and -not $isWildcardMatch) {
            return $false
        }
    }
    
    return $true
}

function Get-ActionsFromPolicyDocuments {
    param([array]$PolicyDocuments)
    
    $actions = @()
    
    foreach ($policyDoc in $PolicyDocuments) {
        if ($policyDoc.Document -eq "DRY_RUN_POLICY_DOCUMENT") {
            $actions += @("s3:GetObject", "ec2:DescribeInstances") # Mock actions for dry run
            continue
        }
        
        try {
            if ($policyDoc.Document -is [string]) {
                $policy = $policyDoc.Document | ConvertFrom-Json
            } else {
                $policy = $policyDoc.Document
            }
            
            foreach ($statement in $policy.Statement) {
                if ($statement.Effect -eq "Allow") {
                    if ($statement.Action -is [array]) {
                        $actions += $statement.Action
                    } else {
                        $actions += @($statement.Action)
                    }
                }
            }
        }
        catch {
            Write-Log "Error parsing policy document for $($policyDoc.Name): $($_.Exception.Message)" -Level Warning
        }
    }
    
    return $actions | Select-Object -Unique
}

function Test-ActionWildcardMatch {
    param(
        [string]$Action,
        [array]$WildcardActions
    )
    
    foreach ($wildcardAction in $WildcardActions) {
        if ($wildcardAction.EndsWith("*")) {
            $prefix = $wildcardAction.TrimEnd("*")
            if ($Action.StartsWith($prefix)) {
                return $true
            }
        }
    }
    return $false
}

function Compare-PolicyDocuments {
    param($Policy1, $Policy2)
    
    # Simple string comparison for policy documents
    # In production, you might want more sophisticated comparison
    try {
        $json1 = $Policy1 | ConvertTo-Json -Depth 10 -Compress
        $json2 = $Policy2 | ConvertTo-Json -Depth 10 -Compress
        return $json1 -eq $json2
    }
    catch {
        return $false
    }
}

function Generate-AnalysisReport {
    param(
        [array]$GroupDetails,
        [array]$RedundantGroups
    )
    
    $report = @()
    
    # Summary
    $report += @{
        Type = "Summary"
        TotalGroups = $GroupDetails.Count
        RedundantGroups = $RedundantGroups.Count
        GroupsToKeep = $GroupDetails.Count - $RedundantGroups.Count
    }
    
    # Group details
    foreach ($group in $GroupDetails) {
        $isRedundant = $RedundantGroups | Where-Object { $_.RedundantGroup -eq $group.GroupName }
        
        $report += @{
            Type = "GroupDetail"
            GroupName = $group.GroupName
            ManagedPoliciesCount = $group.ManagedPolicies.Count
            InlinePoliciesCount = $group.InlinePolicies.Count
            TotalPolicies = $group.PolicyDocuments.Count
            IsRedundant = $isRedundant -ne $null
            RedundancyReason = if ($isRedundant) { $isRedundant.Reason } else { "Not redundant" }
            SupersetGroup = if ($isRedundant) { $isRedundant.SupersetGroup } else { "N/A" }
        }
    }
    
    return $report
}

function Display-AnalysisSummary {
    param([hashtable]$Results)
    
    Write-Host "`n" -NoNewline
    Write-Host "=== USER GROUP ANALYSIS SUMMARY ===" -ForegroundColor Green
    Write-Host "User: $($Results.UserName)" -ForegroundColor Cyan
    Write-Host "Analysis Time: $($Results.Timestamp)" -ForegroundColor Cyan
    Write-Host "Total Groups: $($Results.Groups.Count)" -ForegroundColor White
    Write-Host "Redundant Groups: $($Results.RedundantGroups.Count)" -ForegroundColor $(if ($Results.RedundantGroups.Count -gt 0) { "Yellow" } else { "Green" })
    
    if ($Results.RedundantGroups.Count -gt 0) {
        Write-Host "`nRedundant Groups Found:" -ForegroundColor Yellow
        foreach ($redundant in $Results.RedundantGroups) {
            Write-Host "  • $($redundant.RedundantGroup) -> Can be removed (covered by: $($redundant.SupersetGroup))" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nNo redundant groups found!" -ForegroundColor Green
    }
    
    Write-Host "`nDetailed results exported to output file." -ForegroundColor Cyan
    Write-Host "=================================`n" -ForegroundColor Green
}

function Export-Results {
    param(
        [hashtable]$Results,
        [string]$Feature
    )
    
    Write-Log "Exporting results to $OutputFormat format" -Level Info
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $baseFileName = "$Feature`_$($Results.UserName)_$timestamp"
    
    # Prepare data for export
    $exportData = @()
    
    # Add summary row
    $summaryRow = [PSCustomObject]@{
        'Analysis Type' = $Feature
        'User Name' = $Results.UserName
        'Total Groups' = $Results.Groups.Count
        'Redundant Groups' = $Results.RedundantGroups.Count
        'Analysis Date' = $Results.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        'Group Name' = "SUMMARY"
        'Group Type' = "Summary"
        'Managed Policies' = ""
        'Inline Policies' = ""
        'Is Redundant' = ""
        'Redundancy Reason' = ""
        'Superset Group' = ""
        'Recommendation' = "See individual groups below"
    }
    $exportData += $summaryRow
    
    # Add group details
    foreach ($group in $Results.Groups) {
        $isRedundant = $Results.RedundantGroups | Where-Object { $_.RedundantGroup -eq $group.GroupName }
        
        $managedPolicyNames = ($group.ManagedPolicies | ForEach-Object { $_.PolicyName }) -join "; "
        $inlinePolicyNames = $group.InlinePolicies -join "; "
        
        $groupRow = [PSCustomObject]@{
            'Analysis Type' = $Feature
            'User Name' = $Results.UserName
            'Total Groups' = ""
            'Redundant Groups' = ""
            'Analysis Date' = ""
            'Group Name' = $group.GroupName
            'Group Type' = "IAM Group"
            'Managed Policies' = $managedPolicyNames
            'Inline Policies' = $inlinePolicyNames
            'Is Redundant' = if ($isRedundant) { "YES" } else { "NO" }
            'Redundancy Reason' = if ($isRedundant) { $isRedundant.Reason } else { "Group is necessary" }
            'Superset Group' = if ($isRedundant) { $isRedundant.SupersetGroup } else { "N/A" }
            'Recommendation' = if ($isRedundant) { 
                if ($isRedundant.SupersetGroup -eq "N/A") { "Remove group (no policies)" } 
                else { "Consider removing group" } 
            } else { "Keep group" }
        }
        $exportData += $groupRow
    }
    
    # Export based on format
    if ($OutputFormat -eq "Excel") {
        Export-ToExcel -Data $exportData -FileName $baseFileName
    } else {
        Export-ToCSV -Data $exportData -FileName $baseFileName
    }
    
    # Also export detailed policy information
    Export-DetailedPolicyInfo -Results $Results -FileName "$baseFileName`_Detailed"
}

function Export-ToExcel {
    param(
        [array]$Data,
        [string]$FileName
    )
    
    try {
        $filePath = Join-Path $Script:OutputPath "$FileName.xlsx"
        
        # Create Excel file with formatting
        $Data | Export-Excel -Path $filePath -WorksheetName "Group Analysis" -AutoSize -TableStyle "Medium2" `
            -ConditionalText @(
                New-ConditionalText -Text "YES" -BackgroundColor "LightCoral"
                New-ConditionalText -Text "Remove group" -BackgroundColor "LightCoral"
                New-ConditionalText -Text "Consider removing" -BackgroundColor "Yellow"
                New-ConditionalText -Text "Keep group" -BackgroundColor "LightGreen"
            )
        
        Write-Log "Results exported to Excel: $filePath" -Level Info
        Write-Host "Excel file created: $filePath" -ForegroundColor Green
    }
    catch {
        Write-Log "Failed to export to Excel: $($_.Exception.Message)" -Level Error
        Write-Log "Falling back to CSV export" -Level Warning
        Export-ToCSV -Data $Data -FileName $FileName
    }
}

function Export-ToCSV {
    param(
        [array]$Data,
        [string]$FileName
    )
    
    $filePath = Join-Path $Script:OutputPath "$FileName.csv"
    
    try {
        $Data | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
        Write-Log "Results exported to CSV: $filePath" -Level Info
        Write-Host "CSV file created: $filePath" -ForegroundColor Green
    }
    catch {
        Write-Log "Failed to export to CSV: $($_.Exception.Message)" -Level Error
    }
}

function Export-DetailedPolicyInfo {
    param(
        [hashtable]$Results,
        [string]$FileName
    )
    
    Write-Log "Exporting detailed policy information" -Level Info
    
    $detailedData = @()
    
    foreach ($group in $Results.Groups) {
        foreach ($policy in $group.PolicyDocuments) {
            $policyRow = [PSCustomObject]@{
                'Group Name' = $group.GroupName
                'Policy Name' = $policy.Name
                'Policy Type' = $policy.Type
                'Policy ARN' = if ($policy.Type -eq "Managed") { $policy.Arn } else { "N/A (Inline)" }
                'Actions Count' = if ($policy.Document -ne "DRY_RUN_POLICY_DOCUMENT") {
                    try {
                        $actions = Get-ActionsFromPolicyDocuments -PolicyDocuments @($policy)
                        $actions.Count
                    } catch { "Unable to parse" }
                } else { "DRY RUN" }
                'Has Wildcards' = if ($policy.Document -ne "DRY_RUN_POLICY_DOCUMENT") {
                    try {
                        $actions = Get-ActionsFromPolicyDocuments -PolicyDocuments @($policy)
                        ($actions | Where-Object { $_ -like "*" }).Count -gt 0
                    } catch { "Unknown" }
                } else { "DRY RUN" }
            }
            $detailedData += $policyRow
        }
    }
    
    if ($OutputFormat -eq "Excel") {
        $filePath = Join-Path $Script:OutputPath "$FileName.xlsx"
        try {
            $detailedData | Export-Excel -Path $filePath -WorksheetName "Policy Details" -AutoSize -TableStyle "Medium6"
            Write-Log "Detailed policy info exported to Excel: $filePath" -Level Info
        }
        catch {
            Write-Log "Failed to export detailed info to Excel, using CSV" -Level Warning
            $filePath = Join-Path $Script:OutputPath "$FileName.csv"
            $detailedData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
        }
    } else {
        $filePath = Join-Path $Script:OutputPath "$FileName.csv"
        $detailedData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
        Write-Log "Detailed policy info exported to CSV: $filePath" -Level Info
    }
}

#endregion

#region Main Execution

function Main {
    try {
        # Initialize framework
        Initialize-Framework
        
        # Initialize AWS session
        $awsBaseCommand = Initialize-AWSSession
        
        # Execute requested feature
        switch ($Feature) {
            "UserGroupAnalysis" {
                if (!$UserName) {
                    Write-Log "UserName parameter is required for UserGroupAnalysis feature" -Level Error
                    throw "UserName parameter is required for UserGroupAnalysis feature"
                }
                
                $results = Invoke-UserGroupAnalysis -UserName $UserName
                
                Write-Log "Analysis completed successfully" -Level Info
                
                if ($DryRun) {
                    Write-Host "`n[DRY RUN COMPLETED] No actual AWS commands were executed." -ForegroundColor Magenta
                    Write-Host "In a real run, the script would have:" -ForegroundColor Cyan
                    Write-Host "  • Retrieved groups for user: $UserName" -ForegroundColor White
                    Write-Host "  • Analyzed group policies and permissions" -ForegroundColor White
                    Write-Host "  • Identified redundant groups" -ForegroundColor White
                    Write-Host "  • Generated detailed reports" -ForegroundColor White
                }
            }
            
            default {
                Write-Log "Unknown feature: $Feature" -Level Error
                throw "Unknown feature: $Feature"
            }
        }
        
    }
    catch {
        Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Debug
        
        Write-Host "`nScript execution failed!" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nCheck the log file for detailed information: $Script:LogFile" -ForegroundColor Yellow
        
        exit 1
    }
    finally {
        # Cleanup
        if ($Script:SessionCredentials) {
            Write-Log "Cleaning up session credentials" -Level Info
            $env:AWS_ACCESS_KEY_ID = $null
            $env:AWS_SECRET_ACCESS_KEY = $null
            $env:AWS_SESSION_TOKEN = $null
        }
        
        $duration = (Get-Date) - $Script:StartTime
        Write-Log "Script execution completed in $($duration.TotalSeconds) seconds" -Level Info
        Write-Log "=== AWS Group Analysis Session Ended ===" -Level Info
    }
}

# Execute main function if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Main
}

#endregion

<#
USAGE EXAMPLES:

1. Basic user group analysis:
   .\AWS-GroupAnalyzer.ps1 -Feature UserGroupAnalysis -UserName "john.doe" -AssumeRole "arn:aws:iam::123456789012:role/ReadOnlyRole"

2. Analysis with Excel output and custom retention:
   .\AWS-GroupAnalyzer.ps1 -Feature UserGroupAnalysis -UserName "john.doe" -AssumeRole "arn:aws:iam::123456789012:role/ReadOnlyRole" -OutputFormat Excel -LogRetentionDays 30

3. Dry run to test commands:
   .\AWS-GroupAnalyzer.ps1 -Feature UserGroupAnalysis -UserName "john.doe" -AssumeRole "arn:aws:iam::123456789012:role/ReadOnlyRole" -DryRun

4. Skip confirmation prompts:
   .\AWS-GroupAnalyzer.ps1 -Feature UserGroupAnalysis -UserName "john.doe" -AssumeRole "arn:aws:iam::123456789012:role/ReadOnlyRole" -SkipConfirmation

5. Use effective permissions analysis:
   .\AWS-GroupAnalyzer.ps1 -Feature UserGroupAnalysis -UserName "john.doe" -AssumeRole "arn:aws:iam::123456789012:role/ReadOnlyRole" -ExactPolicyMatch $false -IncludeEffectivePermissions $true

SAFETY FEATURES:
- All commands are displayed before execution for user confirmation
- Dry-run mode available for testing
- Comprehensive logging with configurable retention
- Read-only operations only
- Session credential cleanup
- Detailed error handling and logging
- Cross-account role assumption support

ADDING NEW FEATURES:
To add a new feature, create a new function following the pattern:
1. Add the feature name to the ValidateSet for the Feature parameter
2. Create an Invoke-[FeatureName] function
3. Add a new case in the Main function switch statement
4. Follow the same error handling and logging patterns

The framework handles:
- AWS session management
- Logging and cleanup
- Safe command execution
- Result export
- Error handling
#>