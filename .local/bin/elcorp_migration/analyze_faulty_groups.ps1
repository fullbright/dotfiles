# Requires: ActiveDirectory module
Import-Module ActiveDirectory

# Input and output files
$groupFile = "groups_to_analyze.txt"
$logFile = "group_query_log.txt"
$summaryCsv = "group_query_summary.csv"
$membersCsv = "group_members.csv"

# Initialize log and CSV files
"" | Out-File $logFile
"GroupName,Status,Error,FaultyMember" | Out-File $summaryCsv
"GroupName,MemberDN" | Out-File $membersCsv

# Read group names
$groups = Get-Content $groupFile

foreach ($group in $groups) {
    Write-Host "Processing group: $group"
    Add-Content $logFile "[$(Get-Date)] Processing group: $group"

    try {
        $members = Get-ADGroupMember -Identity $group -server europe.essilor.group -ErrorAction Stop

        foreach ($member in $members) {
            $memberDN = $member.DistinguishedName
            Add-Content $membersCsv "$group,$memberDN"

            # Check for FSP
            if ($memberDN -like "CN=S-1-5-21*,CN=ForeignSecurityPrincipals,*") {
                Add-Content $logFile "[$(Get-Date)] FSP detected: $memberDN"
            }
        }

        Add-Content $summaryCsv "$group,Success,,"
    }
    catch {
        $errorMessage = $_.Exception.Message
        $faultyMember = ""

        # Try to extract FSP SID from error message
        if ($errorMessage -match "CN=S-1-5-\d+-\d+-\d+-\d+") {
            $faultyMember = $matches[0]
        }

        Add-Content $summaryCsv "$group,Failed,""$errorMessage"",""$faultyMember"""
        Add-Content $logFile "[$(Get-Date)] ERROR: $errorMessage"
    }

    # Wait random time between 5 and 15 seconds
    $waitTime = Get-Random -Minimum 5 -Maximum 15
    Write-Host "Waiting $waitTime seconds..."
    Start-Sleep -Seconds $waitTime
}