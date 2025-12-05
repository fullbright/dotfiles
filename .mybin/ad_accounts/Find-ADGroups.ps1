# Find-ADGroups.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]$Tokens,

    [string]$ADServer = "europe.essilor.group"
)

# Split the tokens by comma and trim whitespace
$tokenList = $Tokens.Split(",") | ForEach-Object { $_.Trim() }

# Loop through each token and query AD groups
foreach ($token in $tokenList) {
    Write-Host "Searching for groups with token: $token"
    try {
        $groups = Get-ADGroup -Filter "name -like '$token'" -Server $ADServer
        if ($groups) {
            $groups | Select-Object Name, DistinguishedName
        } else {
            Write-Host "No groups found for token: $token"
        }
    } catch {
        Write-Host "Error querying token '$token': $_"
    }
}