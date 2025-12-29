# Define configuration variables
$assetsPath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\"
$inputJsonFileName = "group-permissions-v3.json"
$outputJsonFileName = "permission-inclusion-analysis-v3.json"
$sleepSeconds = 1  # Seconds to sleep (if needed for future extensions)

# Construct file paths
$inputJsonFilePath = Join-Path -Path $assetsPath -ChildPath $inputJsonFileName
$outputJsonFilePath = Join-Path -Path $assetsPath -ChildPath $outputJsonFileName

# Read the JSON file
$jsonData = Get-Content -Path $inputJsonFilePath -Raw | ConvertFrom-Json

# Initialize an array to hold group permission details
$groupPermissionDetails = @()

# Helper function to compare resources (is resource1 more permissive than resource2?)
function Test-ResourceInclusion {
    param ($Resource1, $Resource2)
    if ($Resource1 -eq "*" -or $Resource1 -eq $Resource2) { return $true }
    if ($Resource1 -is [System.Array] -and $Resource2 -isnot [System.Array]) {
        return $Resource2 -in $Resource1
    }
    if ($Resource1 -isnot [System.Array] -and $Resource2 -is [System.Array]) {
        return $false
    }
    if ($Resource1 -is [System.Array] -and $Resource2 -is [System.Array]) {
        foreach ($r2 in $Resource2) {
            if ($r2 -notin $Resource1 -and $r2 -ne "*") { return $false }
        }
        return $true
    }
    return $false
}

# Helper function to compare conditions (is condition1 more permissive than condition2?)
function Test-ConditionInclusion {
    param ($Condition1, $Condition2)
    if (-not $Condition2) { return $true }  # No condition in group2 is always included
    if (-not $Condition1) { return $false }  # Group1 has no condition but group2 does
    foreach ($key2 in $Condition2.Keys) {
        if (-not $Condition1.ContainsKey($key2)) { return $false }
        foreach ($subKey2 in $Condition2[$key2].Keys) {
            if (-not $Condition1[$key2].ContainsKey($subKey2)) { return $false }
            $val1 = $Condition1[$key2][$subKey2]
            $val2 = $Condition2[$key2][$subKey2]
            if ($val1 -is [System.Array] -and $val2 -isnot [System.Array]) {
                if ($val2 -notin $val1) { return $false }
            } elseif ($val1 -isnot [System.Array] -and $val2 -is [System.Array]) {
                return $false
            } elseif ($val1 -is [System.Array] -and $val2 -is [System.Array]) {
                foreach ($v2 in $val2) {
                    if ($v2 -notin $val1) { return $false }
                }
            } elseif ($val1 -ne $val2) {
                return $false
            }
        }
    }
    return $true
}

# Process each group to extract permissions
foreach ($group in $jsonData.Groups) {
    $groupName = $group.GroupName
    Write-Host "Processing group $groupName"

    # Extract permissions (actions, resources, conditions) from inline and attached policies
    $permissions = @()
    foreach ($policy in $group.InlinePolicies) {
        if ($policy.Document.Statement) {
            $statements = $policy.Document.Statement
            if ($statements -isnot [System.Array]) { $statements = @($statements) }
            foreach ($statement in $statements) {
                if ($statement.Effect -eq "Allow") {
                    $actions = if ($statement.Action -is [System.Array]) { $statement.Action } else { @($statement.Action) }
                    $resources = if ($statement.Resource -is [System.Array]) { $statement.Resource } else { @($statement.Resource) }
                    $permissions += [PSCustomObject]@{
                        Actions   = $actions
                        Resources = $resources
                        Condition = $statement.Condition
                    }
                }
            }
        }
    }
    foreach ($policy in $group.AttachedPolicies) {
        if ($policy.Document.Statement) {
            $statements = $policy.Document.Statement
            if ($statements -isnot [System.Array]) { $statements = @($statements) }
            foreach ($statement in $statements) {
                if ($statement.Effect -eq "Allow") {
                    $actions = if ($statement.Action -is [System.Array]) { $statement.Action } else { @($statement.Action) }
                    $resources = if ($statement.Resource -is [System.Array]) { $statement.Resource } else { @($statement.Resource) }
                    $permissions += [PSCustomObject]@{
                        Actions   = $actions
                        Resources = $resources
                        Condition = $statement.Condition
                    }
                }
            }
        }
    }

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
            $isSubset = $true

            foreach ($perm2 in $group2Permissions) {
                $perm2Matched = $false
                foreach ($perm1 in $group1Permissions) {
                    # Check if all actions in perm2 are in perm1
                    $actionsMatch = $true
                    foreach ($action2 in $perm2.Actions) {
                        if ($action2 -notin $perm1.Actions) {
                            $actionsMatch = $false
                            break
                        }
                    }
                    # Check resources and conditions if actions match
                    if ($actionsMatch) {
                        $resourcesMatch = Test-ResourceInclusion -Resource1 $perm1.Resources -Resource2 $perm2.Resources
                        $conditionsMatch = Test-ConditionInclusion -Condition1 $perm1.Condition -Condition2 $perm2.Condition
                        if ($resourcesMatch -and $conditionsMatch) {
                            $perm2Matched = $true
                            break
                        }
                    }
                }
                if (-not $perm2Matched) {
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