# Get-S3BucketMetadata.ps1
# Purpose: Collect minimal metadata for AWS S3 buckets using AWS CLI for decommissioning analysis.
# Outputs: CSV with bucket metadata and timestamped logs.

# Configurable variables
$AwsProfile = "essilor-calp-prd-admin"  # AWS CLI profile name
$OutputDir = "c:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.011.PRJ.ftj_automation\"  # Directory for CSV and logs
$LogFile = Join-Path -Path $OutputDir -ChildPath ("S3MetadataLog_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
$CsvFile = Join-Path -Path $OutputDir -ChildPath ("S3BucketMetadata_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv")

# Ensure AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI not found. Please install AWS CLI and configure the profile."
    exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Function to write timestamped log
function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Output $LogMessage | Out-File -FilePath $LogFile -Append
}

# Initialize log
Write-Log "Starting S3 bucket metadata collection with profile: $AwsProfile"

# Get list of all S3 buckets
Write-Log "Fetching list of S3 buckets..."
$BucketsJson = aws s3api list-buckets --profile $AwsProfile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "Error listing buckets: $BucketsJson"
    Write-Error "Failed to list buckets. Check AWS CLI configuration and profile."
    exit 1
}

$Buckets = ($BucketsJson | ConvertFrom-Json).Buckets
Write-Log "Found $($Buckets.Count) buckets."

# Initialize CSV content
$CsvContent = @()
$CsvHeaders = "BucketName,SectionTag,CreationDate,LastModified,Region"

# Process each bucket
foreach ($Bucket in $Buckets) {
    $BucketName = $Bucket.Name
    $CreationDate = $Bucket.CreationDate
    Write-Log "Processing bucket: $BucketName"

    # Get bucket region
    $RegionJson = aws s3api get-bucket-location --bucket $BucketName --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Error getting region for $BucketName : $RegionJson"
        $Region = "Unknown"
    } else {
        $Region = ($RegionJson | ConvertFrom-Json).LocationConstraint
        if (-not $Region) { $Region = "us-east-1" }  # Default for us-east-1
    }

    # Get section tag
    $TagsJson = aws s3api get-bucket-tagging --bucket $BucketName --profile $AwsProfile 2>&1
    $SectionTag = "Unknown"
    if ($LASTEXITCODE -eq 0) {
        $Tags = ($TagsJson | ConvertFrom-Json).TagSet
        $SectionTag = ($Tags | Where-Object { $_.Key -eq "section" }).Value
		$EnvironmentTag = ($Tags | Where-Object { $_.Key -eq "environment" }).Value
		$DomainTag = ($Tags | Where-Object { $_.Key -eq "domain" }).Value
		$LongcodeTag = ($Tags | Where-Object { $_.Key -eq "longcode" }).Value
		$OwnerTag = ($Tags | Where-Object { $_.Key -eq "owner" }).Value
		$IssTag = ($Tags | Where-Object { $_.Key -eq "iss" }).Value
        if (-not $SectionTag) { $SectionTag = "Unknown" }
		if (-not $EnvironmentTag) { $EnvironmentTag = "Unknown" }
		if (-not $DomainTag) { $DomainTag = "Unknown" }
		if (-not $LongcodeTag) { $LongcodeTag = "Unknown" }
		if (-not $OwnerTag) { $OwnerTag = "Unknown" }
		if (-not $IssTag) { $IssTag = "Unknown" }
    } else {
        Write-Log "No tags or error for $BucketName : $TagsJson"
    }

    # Get last modified date (single object query to minimize cost)
    $ObjectsJson = aws s3api list-objects-v2 --bucket $BucketName --max-items 1 --profile $AwsProfile 2>&1
    $LastModified = "Unknown"
    if ($LASTEXITCODE -eq 0) {
        $Objects = ($ObjectsJson | ConvertFrom-Json).Contents
        if ($Objects) {
            $LastModified = $Objects.LastModified
        } else {
            Write-Log "No objects found in $BucketName"
            $LastModified = "Empty"
        }
    } else {
        Write-Log "Error listing objects for $BucketName : $ObjectsJson"
    }

    # Add to CSV content
    $CsvContent += [PSCustomObject]@{
        BucketName   = $BucketName
        SectionTag   = $SectionTag
		EnvironmentTag   = $EnvironmentTag
		DomainTag   = $DomainTag
		LongcodeTag  = $LongcodeTag
		OwnerTag     = $OwnerTag
		IssTag       = $IssTag
        CreationDate = $CreationDate
        LastModified = $LastModified
        Region       = $Region
    }
}

# Export to CSV
Write-Log "Exporting metadata to $CsvFile"
$CsvContent | Export-Csv -Path $CsvFile -NoTypeInformation
Write-Log "Metadata collection completed. CSV saved to $CsvFile"

# Output completion message
Write-Output "Metadata collection completed. CSV saved to $CsvFile. Log saved to $LogFile."