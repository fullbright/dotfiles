param (
    [string]$myPath = "C:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.096.PRJ.schemas_d_architecture\Q2_2025_route53"  # Default folder path
)

# Normalize path to absolute
try {
    $ResolvedPath = (Resolve-Path -Path $myPath).Path
} catch {
    Write-Host "ERROR: The folder '$Path' does not exist." -ForegroundColor Red
    exit 1
}

# Logging setup
$LogFile = Join-Path -Path $env:TEMP -ChildPath ("route53_log_{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
#function Log {
#    param([string]$Message)
#    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#    "$timestamp - $Message" | Tee-Object -FilePath $LogFile -Append
#}

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
	Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

# Ensure ImportExcel is available
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "Installing required module: ImportExcel..."
    Install-Module -Name ImportExcel -Scope CurrentUser -Force
}
Import-Module ImportExcel

Log "Scanning folder: $ResolvedPath"

# Helper function: Get latest file by prefix
function Get-LatestCsv {
    param (
        [string]$Prefix
    )

    $files = Get-ChildItem -Path "$ResolvedPath" -Filter "$Prefix*.csv" -File
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

# Map file prefixes to worksheet names
#$Mapping = @{
#    "rxds-a_domains_"       = "rxds-a.com"
#    "rxds-b_domains_"       = "rxds-b.com"
#    "rxdigitalplatform.co_" = "rxdigitalplatform.com"
#}

$Mapping = [ordered]@{
    "rxdigitalplatform.co_" = "rxdigitalplatform.com"
    "rxds-a_domains_"       = "rxds-a.com"
    "rxds-b_domains_"       = "rxds-b.com"
}

# Prepare data
$ExcelData = @{}
foreach ($prefix in $Mapping.Keys) {
    $file = Get-LatestCsv -Prefix $prefix
	Log "lastest csv found = $file"
    if (-not $file) {
		Log "Warning: No file found for prefix '$prefix'. Skipping."
		continue
	}

	if (-not (Test-Path $file)) {
		Log "Warning: File path '$file' does not exist. Skipping."
		continue
	}

	try {
		$csv = Import-Csv -Path $file
		if ($csv -and $csv[0].PSObject.Properties.Name.Count -ge 6) {
			#$filtered = $csv | Where-Object { $_.type -in @("A", "CNAME") }
			#$ExcelData[$Mapping[$prefix]] = $filtered
			$filtered = $csv | Where-Object { $_.type -in @("A", "CNAME") }

			# Remove TTL column
			$cleaned = $filtered | ForEach-Object {
				$_.PSObject.Properties.Remove("TTL")
				$_
			}

			$ExcelData[$Mapping[$prefix]] = $cleaned

			Log "Loaded $($filtered.Count) filtered records into sheet '$($Mapping[$prefix])'"
		} else {
			Log "Warning: File '$file' has insufficient columns or empty content."
		}
	}
	catch {
		Log "Error reading CSV file '$file': $_"
	}

}

if ($ExcelData.Count -eq 0) {
    Log "No valid CSV files to process. Exiting."
    Write-Host "No valid data found. Exiting." -ForegroundColor Yellow
    Write-Host "Log file: $LogFile"
    exit 1
}

# Output Excel file path
$outputFile = Join-Path -Path $ResolvedPath -ChildPath ("route53_rxds_{0}.xlsx" -f (Get-Date -Format "yyyyMMdd-HHmm"))

if (Test-Path $outputFile) {
    Remove-Item -Path $outputFile -Force
    Log "Deleted existing Excel file: $outputFile"
}

Log "Creating Excel file: $outputFile"

# Export each worksheet
#$first = $true
#foreach ($sheet in $ExcelData.Keys) {
#    $ExcelData[$sheet] | Export-Excel -Path $outputFile -WorksheetName $sheet -AutoSize -AutoFilter -Append:(!$first)
#    $first = $false
#}

# ---- Add Info tab ----

# Format date as "19th of March 2025"
function Get-FormattedDate {
    $date = Get-Date
    $day = $date.Day
    $suffix = switch ($day % 10) {
        1 { if ($day -ne 11) { "st" } else { "th" } }
        2 { if ($day -ne 12) { "nd" } else { "th" } }
        3 { if ($day -ne 13) { "rd" } else { "th" } }
        default { "th" }
    }
	$en = New-Object System.Globalization.CultureInfo("en-US")
	$monthName = $en.DateTimeFormat.MonthNames[(Get-Date).Month - 1]

    return "{0}{1} of {2} {3}" -f $day, $suffix, $monthName, $date.Year
}

$infoSheet = @()
$infoSheet += [PSCustomObject]@{ Info = "Extraction done the $(Get-FormattedDate)" }
$infoSheet += [PSCustomObject]@{ Info = "One sheet per domain" }

foreach ($tab in $Mapping.Values) {
   $infoSheet += [PSCustomObject]@{ Info = $tab }
}

# Export info tab with formatting
$infoSheet | Export-Excel -Path $outputFile -WorksheetName "extraction date" -AutoSize -AutoFilter -BoldTopRow -TitleBackgroundColor 'DarkBlue'
Log "Added Info tab"

# Create raw data as array of strings (no headers)
# $infoLines = @()
# $infoLines += "Extraction done the $(Get-FormattedDate)"
# $infoLines += "One sheet per domain"
# $infoLines += $Mapping.Values

# # Write lines to temp sheet
# $wsName = "extraction date"
# $tempFile = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName() + ".xlsx")
# $infoLines | Export-Excel -Path $tempFile -WorksheetName $wsName -Show:$false -NoHeader

# # Open Excel package to format A1
# $pkg = Open-ExcelPackage -Path $tempFile
# $sheet = $pkg.Workbook.Worksheets[$wsName]
# $sheet.Cells["A1"].Style.Font.Bold = $true
# $sheet.Cells["A1"].Style.Fill.PatternType = 'Solid'
# $sheet.Cells["A1"].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::DarkBlue)
# $sheet.Cells["A1"].Style.Font.Color.SetColor([System.Drawing.Color]::White)

# # Save and move to final file
# Close-ExcelPackage -ExcelPackage $pkg -Path $tempFile
# Move-Item -Path $tempFile -Destination $outputFile -Force

# Log "Added Info tab with custom formatting"




#$first = $true
#foreach ($prefix in $Mapping.Keys) {
#    $sheet = $Mapping[$prefix]
#    if ($ExcelData.ContainsKey($sheet)) {
#        $ExcelData[$sheet] | Export-Excel -Path $outputFile -WorksheetName $sheet -AutoSize -AutoFilter -Append:(!$first)
#        $first = $false
#    }
#}

foreach ($prefix in $Mapping.Keys) {
    $sheet = $Mapping[$prefix]
    if ($ExcelData.ContainsKey($sheet)) {
        $ExcelData[$sheet] | Export-Excel -Path $outputFile -WorksheetName $sheet -AutoSize -AutoFilter -Append
    }
}


Log "Excel file created successfully: $outputFile"
Write-Host "`nDone. Excel file saved at: $outputFile"
Write-Host "Log file: $LogFile"

Write-Host ""
Write-Host "Excel file created: $outputFile"
Write-Host "Please open the file and verify the data."
Write-Host "If everything looks good and you'd like to generate the final version,"
Write-Host "type 'yes' and press Enter. Anything else will cancel final generation."

$response = Read-Host "Generate final version as Route53_RxDS.xlsx?"

if ($response -eq "yes") {
    $finalPath = Join-Path -Path $ResolvedPath -ChildPath "Route53_RxDS.xlsx"
    Copy-Item -Path $outputFile -Destination $finalPath -Force
    Log "Final version created: $finalPath"
    Write-Host "Final Excel file saved as: $finalPath"
} else {
    Log "User cancelled final file generation."
    Write-Host "Final file generation skipped."
}
