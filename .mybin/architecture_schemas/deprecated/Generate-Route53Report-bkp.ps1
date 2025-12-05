param (
    [string]$Path = "C:\CSV\Input"  # Default folder path
)

# Ensure required module is available
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "Installing required module: ImportExcel..."
    Install-Module -Name ImportExcel -Scope CurrentUser -Force
}
Import-Module ImportExcel

# Logging setup
$LogFile = Join-Path -Path $env:TEMP -ChildPath "route53_log_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

# Validate path
if (-not (Test-Path $Path)) {
    Log "Error: The folder '$Path' does not exist."
    Write-Host "The folder '$Path' does not exist. Aborting." -ForegroundColor Red
    Write-Host "Log: $LogFile"
    exit 1
}

Log "Scanning folder: $Path"

# Helper function: Get latest file by prefix
function Get-LatestCsv {
    param (
        [string]$Prefix
    )
    $files = Get-ChildItem -Path $Path -Filter "$Prefix*.csv"
    if ($files.Count -eq 0) {
        Log "No files found for prefix: $Prefix"
        return $null
    }

    $latest = $files | Sort-Object {
        ($_ -replace "$Prefix", "") -replace '\.csv', '' -as [int64]
    } -Descending | Select-Object -First 1

    Log "Selected file for '$Prefix': $($latest.Name)"
    return $latest.FullName
}

# Mapping prefixes to sheet names
$Mapping = @{
    "rxds-a_domains_"            = "rxds-a.com"
    "rxds-b_domains_"            = "rxds-b.com"
    "rxdigitalplatform.co_"      = "rxdigitalplatform.com"
}

# Prepare data for export
$ExcelData = @{}
foreach ($prefix in $Mapping.Keys) {
    $file = Get-LatestCsv -Prefix $prefix
    if ($file) {
		Log "importing file $file"
        $csv = Import-Csv "$file"
        if ($csv -and $csv[0].PSObject.Properties.Name.Count -ge 6) {
            $filtered = $csv | Where-Object { $_.type -in @("A", "CNAME") }
            $ExcelData[$Mapping[$prefix]] = $filtered
            Log "Loaded $($filtered.Count) filtered records into sheet '$($Mapping[$prefix])'"
        }
        else {
            Log "File '$file' does not have at least 6 columns."
        }
    }
}

if ($ExcelData.Count -eq 0) {
    Log "No valid CSV files to process. Exiting."
    Write-Host "No valid data found. Exiting." -ForegroundColor Yellow
    Write-Host "Log file: $LogFile"
    exit 1
}

# Generate Excel output
$outputFile = Join-Path -Path $Path -ChildPath ("route53_rxds_{0}.xlsx" -f (Get-Date -Format "yyyyMMdd-HHmm"))
if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
    Log "Existing output file deleted: $outputFile"
}

Log "Creating Excel file: $outputFile"

# Export sheets
$first = $true
foreach ($sheet in $ExcelData.Keys) {
    $ExcelData[$sheet] | Export-Excel -Path $outputFile -WorksheetName $sheet -AutoSize -AutoFilter -Append:(!$first)
    $first = $false
}

Log "Excel file created: $outputFile"
Write-Host "Done! Excel file saved at: $outputFile" -ForegroundColor Green
Write-Host "Log file: $LogFile"
