# mRemoteNG XML Configuration Generator using PSmRemoteNG
# This script creates a mRemoteNG XML config file with RDP connection to 10.0.0.3:50822

# First, install the PSmRemoteNG module if not already installed
if (-not (Get-Module -ListAvailable -Name PSmRemoteNG)) {
    Write-Host "Installing PSmRemoteNG module..." -ForegroundColor Green
    Install-Module -Name PSmRemoteNG -Repository PSGallery -Force -AllowClobber
}

# Import the PSmRemoteNG module
Import-Module PSmRemoteNG

# Create a new root node (this will be the root container for connections)
$rootNode = New-MRNGRootNode -Name "My Connections"

# Create a new RDP connection with the specified parameters
# Note: The Port parameter must be specified explicitly since we're using a custom port
$connection = New-MRNGConnection -Name "Server 10.0.0.3" -Hostname "10.0.0.3" -Protocol "RDP" -Description "RDP connection to 10.0.0.3 on port 50822"

# Set the custom port (50822) after creation since New-MRNGConnection sets default port for RDP (3389)
$connection.Port = 50822

# Add the connection to the root node
$rootNode.AddChild($connection)

# Export the configuration to XML file
$outputPath = "mRemoteNG_Config.xml"
Export-MRNGConnectionFile -RootNode $rootNode -Path $outputPath

Write-Host "mRemoteNG XML configuration file has been created: $outputPath" -ForegroundColor Green
Write-Host "Connection details:" -ForegroundColor Yellow
Write-Host "  - Server: 10.0.0.3" -ForegroundColor White
Write-Host "  - Port: 50822" -ForegroundColor White
Write-Host "  - Protocol: RDP" -ForegroundColor White

# Optional: Display the XML content
if (Test-Path $outputPath) {
    Write-Host "`nXML Content Preview:" -ForegroundColor Cyan
    Get-Content $outputPath | Select-Object -First 20
    Write-Host "..." -ForegroundColor Gray
    Write-Host "`nFull XML file saved to: $(Resolve-Path $outputPath)" -ForegroundColor Green
}