# Define variables for input and output file paths
$assetsPath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\"
$inputJsonFilePath = Join-Path $assetsPath "sergio.afanou-essilor.com-aggregated_results.json"
$outputJsonFilePath = Join-Path $assetsPath "sergio.afanou-essilor.com-aggregated_results-group-policy-comparison.json"

# Read the JSON file containing aggregated group information
$jsonData = Get-Content -Path $inputJsonFilePath -Raw | ConvertFrom-Json

# Initialize an array to hold group policy details and inclusion analysis
$groupPolicyDetails = @()

# Process each group to combine inline and attached policies
foreach ($group in $jsonData.Groups) {
    $groupName = $group.GroupName
    Write-Host "Processing group $groupName"

    # Combine inline and attached policies into a single list
    $policies = @()
    if ($group.InlinePolicies) {
        $policies += $group.InlinePolicies
    }
    if ($group.AttachedPolicies) {
        $policies += $group.AttachedPolicies | ForEach-Object { $_.PolicyName }
    }
    $policies = $policies | Sort-Object -Unique

    # Store group details
    $groupPolicyDetails += [PSCustomObject]@{
        GroupName = $groupName
        Policies  = $policies
    }
}

# Analyze policy inclusion between groups
$inclusionAnalysis = @()
foreach ($group1 in $groupPolicyDetails) {
    $group1Policies = $group1.Policies
    $includedGroups = @()

    foreach ($group2 in $groupPolicyDetails) {
        if ($group1.GroupName -ne $group2.GroupName) {
            $group2Policies = $group2.Policies
            # Check if group2's policies are fully included in group1's policies
            $isSubset = $true
            foreach ($policy in $group2Policies) {
                if ($policy -notin $group1Policies) {
                    $isSubset = $false
                    break
                }
            }
            if ($isSubset -and $group2Policies.Count -gt 0) {
                $includedGroups += [PSCustomObject]@{
                    IncludedGroup = $group2.GroupName
                    PolicyCount   = $group2Policies.Count
                }
            }
        }
    }

    $inclusionAnalysis += [PSCustomObject]@{
        GroupName      = $group1.GroupName
        PolicyCount    = $group1Policies.Count
        Policies       = $group1Policies
        IncludesGroups = $includedGroups
    }
}

# Create final output object
$output = [PSCustomObject]@{
    Groups            = $groupPolicyDetails
    InclusionAnalysis  = $inclusionAnalysis
}

# Convert to JSON and save to output file
$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputJsonFilePath -Encoding UTF8

Write-Host "Results saved to $outputJsonFilePath"