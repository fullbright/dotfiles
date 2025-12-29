# Read the JSON file containing group information
$jsonFilePath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\sergio.afanou-essilor.com-groups.json"
$jsonData = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
$awsProfile = "rxds_iam_admin"
$outputFile = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\sergio.afanou-essilor.com-aggregated_results.json"

# Initialize an array to hold group details
$groupDetails = @()

# Iterate through each group
foreach ($group in $jsonData.Groups) {
    $groupName = $group.GroupName
    Write-Host "Processing group $groupName"

    # Get inline group policies
    $inlinePoliciesJson = aws iam list-group-policies --group-name "$groupName" --profile $awsProfile --output json
    $inlinePolicies = $inlinePoliciesJson | ConvertFrom-Json

    # Get attached group policies
    $attachedPoliciesJson = aws iam list-attached-group-policies --group-name "$groupName" --profile $awsProfile --output json
    $attachedPolicies = $attachedPoliciesJson | ConvertFrom-Json

    # Get policy details for attached policies
    $policyDetails = @()
    if ($attachedPolicies.AttachedPolicies) {
        foreach ($policy in $attachedPolicies.AttachedPolicies) {
            $policyArn = $policy.PolicyArn
            $policyVersionJson = aws iam get-policy-version --policy-arn "$policyArn" --version-id (aws iam get-policy --policy-arn "$policyArn" --profile $awsProfile --output json | ConvertFrom-Json).Policy.DefaultVersionId --profile $awsProfile --output json
            $policyDetails += $policyVersionJson | ConvertFrom-Json
        }
    }

    # Create group object
    $groupObject = [PSCustomObject]@{
        GroupName      = $groupName
        InlinePolicies = $inlinePolicies.PolicyNames
        AttachedPolicies = $attachedPolicies.AttachedPolicies | Select-Object PolicyName, PolicyArn
        PolicyDetails  = $policyDetails | Select-Object -Property PolicyVersion.Document
    }

    $groupDetails += $groupObject
    Start-Sleep -Seconds 1  # Throttle API calls
}

# Analyze permission inclusion
$permissionAnalysis = @()
foreach ($group1 in $groupDetails) {
    $group1Permissions = @()
    # Extract all permissions from policy documents
    foreach ($policy in $group1.PolicyDetails) {
        if ($policy.PolicyVersion.Document.Statement) {
            $group1Permissions += $policy.PolicyVersion.Document.Statement | Where-Object { $_.Effect -eq "Allow" } | Select-Object -ExpandProperty Action
        }
    }
    $group1Permissions = $group1Permissions | Sort-Object -Unique

    $inclusion = @()
    foreach ($group2 in $groupDetails) {
        if ($group1.GroupName -ne $group2.GroupName) {
            $group2Permissions = @()
            foreach ($policy in $group2.PolicyDetails) {
                if ($policy.PolicyVersion.Document.Statement) {
                    $group2Permissions += $policy.PolicyVersion.Document.Statement | Where-Object { $_.Effect -eq "Allow" } | Select-Object -ExpandProperty Action
                }
            }
            $group2Permissions = $group2Permissions | Sort-Object -Unique

            # Check if group1's permissions include group2's
            $isSubset = $true
            foreach ($perm in $group2Permissions) {
                if ($perm -notin $group1Permissions) {
                    $isSubset = $false
                    break
                }
            }

            if ($isSubset -and $group2Permissions.Count -gt 0) {
                $inclusion += [PSCustomObject]@{
                    IncludedGroup = $group2.GroupName
                    PermissionCount = $group2Permissions.Count
                }
            }
        }
    }

    $permissionAnalysis += [PSCustomObject]@{
        GroupName         = $group1.GroupName
        PermissionCount   = $group1Permissions.Count
        IncludesGroups    = $inclusion
    }
}

# Create final output object
$output = [PSCustomObject]@{
    Groups            = $groupDetails
    PermissionAnalysis = $permissionAnalysis
}

# Convert to JSON and save
$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Results saved to $outputFile"