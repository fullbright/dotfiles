# Define variables for input and output file paths
$assetsPath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\"
$inputJsonFilePath =  Join-Path $assetsPath "group-permissions-v2.json"
$outputJsonFilePath =  Join-Path $assetsPath "permission-inclusion-analysis-v2.json"

# Read the JSON file
$jsonData = Get-Content -Path $inputJsonFilePath -Raw | ConvertFrom-Json

# Initialize an array to hold group permission details
$groupPermissionDetails = @()

# Process each group to extract permissions
foreach ($group in $jsonData.Groups) {
    $groupName = $group.GroupName
    Write-Host "Processing group $groupName"

    # Extract permissions (actions) from inline and attached policies
    $permissions = @()
    foreach ($policy in $group.InlinePolicies) {
        if ($policy.Document.Statement) {
            $statements = $policy.Document.Statement
            if ($statements -isnot [System.Array]) { $statements = @($statements) }
            $permissions += $statements | 
                Where-Object { $_.Effect -eq "Allow" } | 
                ForEach-Object { 
                    if ($_.Action -is [System.Array]) { $_.Action } else { @($_.Action) }
                }
        }
    }
    foreach ($policy in $group.AttachedPolicies) {
        if ($policy.Document.Statement) {
            $statements = $policy.Document.Statement
            if ($statements -isnot [System.Array]) { $statements = @($statements) }
            $permissions += $statements | 
                Where-Object { $_.Effect -eq "Allow" } | 
                ForEach-Object { 
                    if ($_.Action -is [System.Array]) { $_.Action } else { @($_.Action) }
                }
        }
    }
    $permissions = $permissions | Sort-Object -Unique

    # Store group details
    $groupPermissionDetails += [PSCustomObject]@{
        GroupName   = $groupName
        Permissions = $permissions
    }
}

# Analyze permission inclusion
$inclusionAnalysis = @()
foreach ($group1 in $groupPermissionDetails) {
    $group1Permissions = $group1.Permissions
    $includedGroups = @()

    foreach ($group2 in $groupPermissionDetails) {
        if ($group1.GroupName -ne $group2.GroupName) {
            $group2Permissions = $group2.Permissions
            # Check if group2's permissions are fully included in group1's
            $isSubset = $true
            foreach ($perm in $group2Permissions) {
                if ($perm -notin $group1Permissions) {
                    $isSubset = $false
                    break
                }
            }
            if ($isSubset -and $group2Permissions.Count -gt 0) {
                $includedGroups += [PSCustomObject]@{
                    IncludedGroup   = $group2.GroupName
                    PermissionCount = $group2Permissions.Count
                }
            }
        }
    }

    $inclusionAnalysis += [PSCustomObject]@{
        GroupName       = $group1.GroupName
        PermissionCount = $group1Permissions.Count
        Permissions     = $group1Permissions
        IncludesGroups  = $includedGroups
    }
}

# Create output object
$output = [PSCustomObject]@{
    Groups            = $groupPermissionDetails
    InclusionAnalysis  = $inclusionAnalysis
}

# Save to JSON file
$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputJsonFilePath -Encoding UTF8
Write-Host "Permission inclusion analysis saved to $outputJsonFilePath"