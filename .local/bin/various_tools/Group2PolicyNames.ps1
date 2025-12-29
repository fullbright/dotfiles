# Read the JSON file containing group information
$jsonFilePath = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\sergio.afanou-essilor.com-groups.json"
$jsonData = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json

# Initialize an empty array to hold the aggregated results
$aggregatedResults = @()

# Iterate through each group in the JSON data
foreach ($group in $jsonData.Groups) {
    $groupName = $group.GroupName
	
	Write-Host	"Processing group $groupName"

    # Execute AWS S3 ls command for the current group name
    # The output is captured as a JSON string
    $s3OutputJson = aws iam list-group-policies --group-name "$groupName" --profile rxds_iam_admin --output json
	$s3OutputAttachedJson = aws iam list-attached-group-policies --group-name "$groupName" --profile rxds_iam_admin --output json

    # Convert the S3 command output from JSON string to a PowerShell object
    $s3Results = $s3OutputJson | ConvertFrom-Json
	$s3ResultsAttached = $s3OutputAttachedJson | ConvertFrom-Json

    # Add the group name as a property to each S3 result object
    $s3Results | ForEach-Object {
        #$_.GroupName = $groupName
		$_ | Add-Member -MemberType NoteProperty -Name GroupName -Value "$groupName"
		
		Start-Sleep -Seconds 3
		$_ | Add-Member -MemberType NoteProperty -Name "AttachedPolicies" -Value "$s3ResultsAttached" -PassThru
    }

    # Add the processed S3 results to the aggregated array
    $aggregatedResults += $s3Results
	
	# Sleep a little bit
	Start-Sleep -Seconds 3
}

# Convert the aggregated array of objects to a single JSON string
$aggregatedJson = $aggregatedResults | ConvertTo-Json -Depth 10

# Write the final aggregated JSON to a file
$aggregatedJson | Out-File -FilePath "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\sergio.afanou-essilor.com-aggregated_results.json" -Encoding UTF8   