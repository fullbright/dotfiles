# Define configuration variables
$userName = "sergio.afanou@essilor.com"
$profileName = "rxds_iam_admin"
$assetsPath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\"
$outputJsonFileName = "group-permissions-v3.json"
$sleepSeconds = 1  # Seconds to sleep between AWS API calls

# Ensure assets directory exists
if (-not (Test-Path -Path $assetsPath)) {
    New-Item -Path $assetsPath -ItemType Directory | Out-Null
}

# Construct output file path
$outputJsonFilePath = Join-Path -Path $assetsPath -ChildPath $outputJsonFileName

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
        Start-Sleep -Seconds $sleepSeconds
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
            Start-Sleep -Seconds $sleepSeconds
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