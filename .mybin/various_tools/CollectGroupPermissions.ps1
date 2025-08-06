# Define variables for input and output file paths
$userName = "sergio.afanou@essilor.com"
$profileName = "rxds_iam_admin"
$assetsPath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\"
$outputJsonFilePath = Join-Path $assetsPath  "group-permissions-v2.json"

# Get groups for the user
$groupsJson = aws iam list-groups-for-user --user-name $userName --profile $profileName --output json
$groups = $groupsJson | ConvertFrom-Json

# Initialize an array to hold group details
$groupDetails = @()

# Process each group
foreach ($group in $groups.Groups) {
    $groupName = $group.GroupName
    Write-Host "Processing group $groupName"

    # Get inline policies
    $inlinePoliciesJson = aws iam list-group-policies --group-name $groupName --profile $profileName --output json
    $inlinePolicies = $inlinePoliciesJson | ConvertFrom-Json

    # Get inline policy details
    $inlinePolicyDetails = @()
    foreach ($policyName in $inlinePolicies.PolicyNames) {
        $policyDocumentJson = aws iam get-group-policy --group-name $groupName --policy-name $policyName --profile $profileName --output json
        $policyDocument = ($policyDocumentJson | ConvertFrom-Json).PolicyDocument
        $inlinePolicyDetails += [PSCustomObject]@{
            PolicyName = $policyName
            Document   = $policyDocument
        }
        Start-Sleep -Seconds 1  # Throttle API calls
    }

    # Get attached policies
    $attachedPoliciesJson = aws iam list-attached-group-policies --group-name $groupName --profile $profileName --output json
    $attachedPolicies = $attachedPoliciesJson | ConvertFrom-Json

    # Get attached policy details
    $attachedPolicyDetails = @()
    if ($attachedPolicies.AttachedPolicies) {
        foreach ($policy in $attachedPolicies.AttachedPolicies) {
            $policyArn = $policy.PolicyArn
            $policyVersionId = (aws iam get-policy --policy-arn $policyArn --profile $profileName --output json | ConvertFrom-Json).Policy.DefaultVersionId
            $policyVersionJson = aws iam get-policy-version --policy-arn $policyArn --version-id $policyVersionId --profile $profileName --output json
            $policyDocument = ($policyVersionJson | ConvertFrom-Json).PolicyVersion.Document
            $attachedPolicyDetails += [PSCustomObject]@{
                PolicyName = $policy.PolicyName
                PolicyArn  = $policyArn
                Document   = $policyDocument
            }
            Start-Sleep -Seconds 1  # Throttle API calls
        }
    }

    # Store group details
    $groupDetails += [PSCustomObject]@{
        GroupName          = $groupName
        InlinePolicies     = $inlinePolicyDetails
        AttachedPolicies   = $attachedPolicyDetails
    }
}

# Create output object
$output = [PSCustomObject]@{
    Groups = $groupDetails
}

# Save to JSON file
$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputJsonFilePath -Encoding UTF8
Write-Host "Group and permission details saved to $outputJsonFilePath"

