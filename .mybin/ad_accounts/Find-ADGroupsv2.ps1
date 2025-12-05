
param (
    [Parameter(Mandatory = $true)]
    [string]$Tokens,

    [string]$ADServer = "europe.essilor.group",

    [string]$OutputPath = "C:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.101.PRJ.ftj.ELCORP-migration"
)

# Ensure the ImportExcel module is available
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "The ImportExcel module is required. Please install it using 'Install-Module -Name ImportExcel'."
    exit
}

# Split the tokens by comma and trim whitespace
$tokenList = $Tokens.Split(",") | ForEach-Object { $_.Trim() }

# Initialize an array to hold results
$results = @()

# Loop through each token and query AD groups
foreach ($token in $tokenList) {
    Write-Host "Searching for groups with token: $token"
    try {
        $groups = Get-ADGroup -Filter "name -like '$token'" -Server $ADServer
        foreach ($group in $groups) {
            $results += [PSCustomObject]@{
                Server            = $ADServer
                Name              = $group.Name
                Token             = $token
                DistinguishedName = $group.DistinguishedName
            }
        }
    } catch {
        Write-Host "Error querying token '$token': $_"
    }
}

# Define output Excel file path
$excelFile = Join-Path -Path $OutputPath -ChildPath "ADGroupResults.xlsx"

# Export results to Excel
$results | Export-Excel -Path $excelFile -AutoSize -TableName "ADGroups" -WorksheetName "Results"

Write-Host "Results exported to $excelFile"
