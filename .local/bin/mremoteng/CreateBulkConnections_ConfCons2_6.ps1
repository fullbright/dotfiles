#####################################
# Authors: David Sparer & Jack Denton
# Summary:
#   This is intended to be a template for creating connections in bulk. This uses the serializers directly from the mRemoteNG binaries.
#   You will still need to create the connection info objects, but the library will handle serialization. It is expected that you
#   are familiar with PowerShell. If this is not the case, reach out to the mRemoteNG community for help.
# Usage:
#   Replace or modify the examples that are shown toward the end of the script to create your own connection info objects.
#####################################

# First, install the PSmRemoteNG module if not already installed
if (-not (Get-Module -ListAvailable -Name PSmRemoteNG)) {
    Write-Host "Installing PSmRemoteNG module..." -ForegroundColor Green
    Install-Module -Name PSmRemoteNG -Repository PSGallery -Force -AllowClobber
}

# Import the PSmRemoteNG module
Import-Module PSmRemoteNG


# Helper function to retrieve reusable credentials
function Get-ReusableCredential {
    if (-not $Global:ReusableCredential) {
        $Global:ReusableCredential = Get-Credential -Message "Enter credentials for mRemoteNG connections"
    }
    return $Global:ReusableCredential
}


function ConvertTo-mRNGSerializedXml {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [mRemoteNG.Connection.ConnectionInfo[]]
        $Xml
)

    function Get-ChildNodes {
        Param ($Xml)

        $Xml

        if ($Xml -is [mRemoteNG.Container.ContainerInfo] -and $Xml.HasChildren()) {
            foreach ($Node in $Xml.Children) {
				# Write-Host "Exporting node $Node"
                Get-ChildNodes -Xml $Node
            }
        } else {
				Write-Host "The container has no children or is not a container"
		}
    }

    $AllNodes = Get-ChildNodes -Xml $Xml
    if (
        $AllNodes.Password -or
        $AllNodes.RDGatewayPassword -or
        $AllNodes.VNCProxyPassword
    ) {
        #$Password = Read-Host -Message 'If you have password protected your ConfCons.xml please enter the password here otherwise just press enter' -AsSecureString
		$Password = [securestring]::new()
    }
    else {
        $Password = [securestring]::new()
    }
    $CryptoProvider = [mRemoteNG.Security.SymmetricEncryption.AeadCryptographyProvider]::new()
    $SaveFilter = [mRemoteNG.Security.SaveFilter]::new()
    $ConnectionNodeSerializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionNodeSerializer26]::new($CryptoProvider, $Password, $SaveFilter)
    $XmlSerializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionsSerializer]::new($CryptoProvider, $ConnectionNodeSerializer)

    $RootNode = [mRemoteNG.Tree.Root.RootNodeInfo]::new('Connection')
    foreach ($Node in $Xml) {
		# Write-Host "Pushing each node into the xml tree : $Node"
        $RootNode.AddChild($Node)
    }
    $XmlSerializer.Serialize($RootNode)
}

function New-mRNGConnection {
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    Param (
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter(Mandatory)]
        [string]
        $Hostname,

        [Parameter(Mandatory)]
        [mRemoteNG.Connection.Protocol.ProtocolType]
        $Protocol,

        [Parameter(ParameterSetName = 'Credential')]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName = 'InheritCredential')]
        [switch]
        $InheritCredential,

        [Parameter()]
        [mRemoteNG.Container.ContainerInfo]
        $ParentContainer,

        [Parameter()]
        [switch]
        $PassThru,
		
		[Parameter()]
        [string]
        $Description
    )

    $Connection = [mRemoteNG.Connection.ConnectionInfo]@{
        Name     = $Name
        Hostname = $Hostname
        Protocol = $Protocol
		PreExtApp = "PreConnect-AWSEC2-v3" 
		PostExtApp = "PostDisconnect-AWSEC2-v3"
    }

    if ($Credential) {
        $Connection.Username = $Credential.GetNetworkCredential().UserName
        $Connection.Domain = $Credential.GetNetworkCredential().Domain
        $Connection.Password = $Credential.GetNetworkCredential().Password
    }

    if ($InheritCredential) {
        $Connection.Inheritance.Username = $true
        $Connection.Inheritance.Domain = $true
        $Connection.Inheritance.Password = $true
    }
	
	if ($Description) {
        $Connection.Description = $Description
    }

    if ($ParentContainer) {
        $ParentContainer.AddChild($Connection)

        if ($PSBoundParameters.ContainsKey('PassThru')) {
            $Connection
        }
    }
    else {
        $Connection
    }
	
	#$Connection | Select-Object -Property * | ConvertTo-Json
}

function New-mRNGContainer {
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    Param (
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Credential')]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName = 'InheritCredential')]
        [switch]
        $InheritCredential,

        [Parameter()]
        [mRemoteNG.Container.ContainerInfo]
        $ParentContainer
    )

    $Container = [mRemoteNG.Container.ContainerInfo]@{
        Name = $Name
    }

    if ($Credential) {
        $Container.Username = $Credential.GetNetworkCredential().UserName
        $Container.Domain = $Credential.GetNetworkCredential().Domain
        $Container.Password = $Credential.GetNetworkCredential().Password
    }

    if ($InheritCredential) {
        $Container.Inheritance.Username = $true
        $Container.Inheritance.Domain = $true
        $Container.Inheritance.Password = $true
    }

    if ($ParentContainer) {
        $ParentContainer.AddChild($Container)
    }
    
    $Container
}

function Export-mRNGXml {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $SerializedXml
    )

    $FilePathProvider = [mRemoteNG.Config.DataProviders.FileDataProvider]::new($Path)
    $filePathProvider.Save($SerializedXml)
}




#----------------------------------------------------------------
# Example 1: serialize many connections, no containers
# Here you can define the number of connection info objects to create
# You can also provide a list of desired hostnames and iterate over those

foreach ($Path in 'HKLM:\SOFTWARE\WOW6432Node\mRemoteNG', 'HKLM:\SOFTWARE\mRemoteNG') {
    Try {
        $mRNGPath = (Get-ItemProperty -Path $Path -Name InstallDir -ErrorAction Stop).InstallDir
        break
    }
    Catch {
        continue
    }
}
if (!$mRNGPath) {
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = [System.Windows.Forms.FolderBrowserDialog]@{
        Description         = 'Please select the folder which contains mRemoteNG.exe'
        ShowNewFolderButton = $false
    }
    
    $Response = $FolderBrowser.ShowDialog()
    
    if ($Response.value__ -eq 1) {
        $mRNGPath = $FolderBrowser.SelectedPath
    }
    elseif ($Response.value__ -eq 2) {
        Write-Warning 'A folder containing mRemoteNG.exe has not been selected'
        return
    }
}


# Example usage with reusable credentials and pre/post-connection scripts
#$ReusableCredential = Get-ReusableCredential

Write-Host $mRNGPath 
$null = [System.Reflection.Assembly]::LoadFile((Join-Path -Path $mRNGPath -ChildPath "mRemoteNG.exe"))
Add-Type -Path (Join-Path -Path $mRNGPath -ChildPath "BouncyCastle.Crypto.dll")

# $rootNode = New-MRNGRootNode -Name "My Connections"

$csvgdp = Import-Csv -Path '.\ec2_asset_data.csv' | ? autoscaled -like *NO* | ? longcode -like *gdp_* | ? environment -like *prd*
$Connections = foreach ($i in $csvgdp) {
    # Create new connection
	Write-Host "Many connections : $i"
	
	$serverhostname = "unknown"
	if($i.hostname -ne ""){
		$serverhostname = $i.hostname	
	}
	
	$localportnumber_prefix = "5"
	if($i.region -eq "ca-central-1"){
		$localportnumber_prefix = "6"
	}
	
	$localportnumber = '{0}{1}' -f ($localportnumber_prefix, $serverhostname.Substring($serverhostname.Length - 4))
	$aws_profile = 'rios-{0}' -f ($i.environment)
	$nodedescription = '{0}@{1}@{2}@{3}' -f ($i.instanceid, $localportnumber, $aws_profile, $i.region)
	$nodename = '{0} - {1} - {2}' -f ($i.longcode, $i.name, $serverhostname)
	
	# Create a new RDP connection with the specified parameters
	# Note: The Port parameter must be specified explicitly since we're using a custom port
	$connection = New-MRNGConnection -Name $nodename -Hostname "localhost" -Protocol "RDP" -Description $nodedescription

	# Set the custom port (50822) after creation since New-MRNGConnection sets default port for RDP (3389)
	$connection.Port = $localportnumber

	# Add the connection to the root node
	# $EnvContainer.AddChild($rootNode)
	$connection
}

# Serialize the connections
$SerializedXml = ConvertTo-mRNGSerializedXml -Xml $Connections

# Write the XML to a file ready to import into mRemoteNG
Write-Host "Writing file to $ENV:APPDATA\mRemoteNG\PowerShellGeneratedSerialized.xml"
Export-mRNGXml -Path "$ENV:APPDATA\mRemoteNG\PowerShellGeneratedSerialized.xml" -SerializedXml $SerializedXml

# Now open up mRemoteNG and press Ctrl+O and open up the exported XML file


### For the generation of the Reboot waves files
$csvreboot = Import-Csv -Path '.\ec2_rebootwaves_data.csv'
$waves = $csvreboot | select-object 'Wave' -Unique | ? Wave -ne ""

#$RebootServerCreds = Get-Credential
#$MonthlyRebootServers = New-mRNGContainer -Name 'MonthlyRebootServers' -Credential $RebootServerCreds
#$MonthlyRebootServers = New-mRNGContainer -Name 'MonthlyRebootServers' -Credential $ReusableCredential
$MonthlyRebootServers = New-mRNGContainer -Name 'MonthlyRebootServers'

foreach($wave in $waves){
    write-host "Processing wave $wave"
    $WaveContainer = New-mRNGContainer -Name $wave.Wave.ToUpper() -ParentContainer $MonthlyRebootServers -InheritCredential

    $rebootwave = $csvreboot | ? Wave -eq $wave.Wave
    foreach ($i in $rebootwave) {
        # Create new connection
	    Write-Host "Reboot connection : $i"
	
	    $serverhostname = "unknown"
	    if($i.Hostname -ne ""){
		    $serverhostname = $i.Hostname	
	    }
	
		$localportnumber_prefix = "5"
		if($i.region -eq "ca-central-1"){
			$localportnumber_prefix = "6"
		}
		
		$localportnumber = '{0}{1}' -f ($localportnumber_prefix, $serverhostname.Substring($serverhostname.Length - 4))
		$aws_profile = 'rios-{0}' -f ($i.environment)
		$nodedescription = '{0}@{1}@{2}@{3}' -f ($i.instanceid, $localportnumber, $aws_profile, $i.region)
		$nodename = '{0} - {1} - {2}' -f ($i.longcode, $i.name, $serverhostname)
		
		# Create a new RDP connection with the specified parameters
		# Note: The Port parameter must be specified explicitly since we're using a custom port
		$connection = New-MRNGConnection -Name $nodename -Hostname "localhost" -Protocol "RDP" -Description $nodedescription

		# Set the custom port (50822) after creation since New-MRNGConnection sets default port for RDP (3389)
		$connection.Port = $localportnumber

		# Add the connection to the root node
		$WaveContainer.AddChild($connection)
    }
}



# Serialize the connections
$SerializedXml = ConvertTo-mRNGSerializedXml -Xml $MonthlyRebootServers

# Write the XML to a file ready to import into mRemoteNG
Write-Host "Writing file to $ENV:APPDATA\mRemoteNG\MonthlyRebootPowerShellGeneratedSerialized.xml"
Export-mRNGXml -Path "$ENV:APPDATA\mRemoteNG\MonthlyRebootPowerShellGeneratedSerialized.xml" -SerializedXml $SerializedXml



#----------------------------------------------------------------
# Example 2: serialize a container which has connections
# You can also create containers and add connections and containers to them, which will be nested correctly when serialized
# If you specify the ParentContainer parameter for new connections then there will be no output unless the PassThru parameter is also used

#$ProdServerCreds = Get-Credential
#$RxITDSServers = New-mRNGContainer -Name 'RxITDSServers' -Credential $ProdServerCreds
#$RxITDSServers = New-mRNGContainer -Name 'RxITDSServers' -Credential $ReusableCredential
$RxITDSServers = New-mRNGContainer -Name 'RxITDSServers'

$csv = Import-Csv -Path '.\ec2_asset_data.csv'  | ? autoscaled -like *NO*

$AccountNames = $csv | select-object 'account' -Unique | ? account -ne ""
$regions = $csv | select-object 'region' -Unique | ? region -ne "" # | % { $_.region.Substring(0,2).ToUpper() } | Get-Unique
$longcodes = $csv | select-object 'longcode' -Unique | ? longcode -ne ""
$environments = $csv | select-object 'environment' -Unique | ? environment -ne ""

foreach($region in $regions){
	Write-Host "Processing region $region"
	$RegionContainer = New-mRNGContainer -Name $region.region.Substring(0,2).ToUpper() -ParentContainer $RxITDSServers -InheritCredential
	
	foreach($account in $AccountNames){
	
		Write-Host "  Processing account $account"
		$AccountContainer = New-mRNGContainer -Name $account.account -ParentContainer $RegionContainer -InheritCredential
	
		foreach($longcode in $longcodes){
		
			Write-Host "    Processing longcode $longcode"
			$LongcodeContainer = New-mRNGContainer -Name $longcode.longcode -ParentContainer $AccountContainer -InheritCredential
			
			foreach($environment in $environments){
			
				Write-Host "      Processing environment $environment"
				$EnvContainer = New-mRNGContainer -Name $environment.environment -ParentContainer $LongcodeContainer -InheritCredential
				
				$csvgdp = $csv | ? region -eq $region.region | ? account -eq $account.account | ? longcode -eq $longcode.longcode | ? environment -eq $environment.environment
				foreach ($i in $csvgdp) {
					# Create new connection
					# Write-Host "Many containers ProdServers : $i"
					$processinghost = "        Processing server {0}" -f ($i.name)
					Write-Host $processinghost
					$serverhostname = "unknown"
					if($i.hostname -ne ""){
						$serverhostname = $i.hostname	
					}
	
					$localportnumber_prefix = "5"
					if($i.region -eq "ca-central-1"){
						$localportnumber_prefix = "6"
					}
					
					$localportnumber = '{0}{1}' -f ($localportnumber_prefix, $serverhostname.Substring($serverhostname.Length - 4))
					$aws_profile = 'rios-{0}' -f ($i.environment)
					$nodedescription = '{0}@{1}@{2}@{3}' -f ($i.instanceid, $localportnumber, $aws_profile, $i.region)
					$nodename = '{0} - {1} - {2}' -f ($i.longcode, $i.name, $serverhostname)
					
					# Create a new RDP connection with the specified parameters
					# Note: The Port parameter must be specified explicitly since we're using a custom port
					$connection = New-MRNGConnection -Name $nodename -Hostname "localhost" -Protocol "RDP" -Description $nodedescription

					# Set the custom port (50822) after creation since New-MRNGConnection sets default port for RDP (3389)
					$connection.Port = $localportnumber

					# Add the connection to the root node
					$EnvContainer.AddChild($connection)
				}
			}
		}
	}
}

$DevServers = New-mRNGContainer -Name 'DevServers'

foreach ($i in 1..3) {
    # Create new connection
	# Write-Host "Many containers DevServers : $i"
    $Splat = @{
        Name              = 'DevServer-{0:D2}' -f $i
        Hostname          = 'DevServer-{0:D2}' -f $i
        Protocol          = 'RDP'
        InheritCredential = $true
        ParentContainer   = $DevServers
        PassThru          = $true
    }

    # Specified the PassThru parameter in order to catch the connection and change a property
    $Connection = New-mRNGConnection @Splat
    $Connection.Resolution = 'FullScreen'
}

# Serialize the container
$SerializedXml = ConvertTo-mRNGSerializedXml -Xml $RxITDSServers, $DevServers

# Write the XML to a file ready to import into mRemoteNG
Write-Host "Write file to $ENV:APPDATA\mRemoteNG\PowerShellGenerated.xml"
Export-mRNGXml -Path "$ENV:APPDATA\mRemoteNG\PowerShellGenerated.xml" -SerializedXml $SerializedXml

# Now open up mRemoteNG and press Ctrl+O and open up the exported XML file

<# 

$csvgdp = Import-Csv -Path '.\ec2_asset_data.csv' | ? uses_autoscaling -like *NO* | ? longcode -like *gdp_* | ? environment -like *prd*
$ServersContainer = New-mRNGContainer -Name 'GDP-PRD' -ParentContainer $RxITDSServers -InheritCredential

foreach ($i in $csvgdp) {
    # Create new connection
	# Write-Host "Many containers ProdServers : $i"
    $serverhostname = "unknown"
	if($i.hostname -ne ""){
		$serverhostname = $i.hostname	
	}
	
    $Splat = @{
        Name              = '{0} - {1} - {2}' -f ($i.longcode, $i.InstanceName, $serverhostname)
        Hostname          = $serverhostname
        Protocol          = 'RDP'
        InheritCredential = $true
		ParentContainer   = $ServersContainer
    }
    New-mRNGConnection @Splat
}

$csvgdp = Import-Csv -Path '.\ec2_asset_data.csv' | ? uses_autoscaling -like *NO* | ? longcode -like *gdp_* | ? environment -like *ppr*
$ServersContainer = New-mRNGContainer -Name 'GDP-PPR' -ParentContainer $RxITDSServers -InheritCredential

foreach ($i in $csvgdp) {
    # Create new connection
	# Write-Host "Many containers ProdServers : $i"
    $serverhostname = "unknown"
	if($i.hostname -ne ""){
		$serverhostname = $i.hostname	
	}
	
    $Splat = @{
        Name              = '{0} - {1} - {2}' -f ($i.longcode, $i.InstanceName, $serverhostname)
        Hostname          = $serverhostname
        Protocol          = 'RDP'
        InheritCredential = $true
		ParentContainer   = $ServersContainer
    }
    New-mRNGConnection @Splat
}

$csvgdp = Import-Csv -Path '.\ec2_asset_data.csv' | ? uses_autoscaling -like *NO* | ? longcode -like *gdp_* | ? environment -like *qua*
$ServersContainer = New-mRNGContainer -Name 'GDP-QUA' -ParentContainer $RxITDSServers -InheritCredential

foreach ($i in $csvgdp) {
    # Create new connection
	# Write-Host "Many containers ProdServers : $i"
    $serverhostname = "unknown"
	if($i.hostname -ne ""){
		$serverhostname = $i.hostname	
	}
	
    $Splat = @{
        Name              = '{0} - {1} - {2}' -f ($i.longcode, $i.InstanceName, $serverhostname)
        Hostname          = $serverhostname
        Protocol          = 'RDP'
        InheritCredential = $true
		ParentContainer   = $ServersContainer
    }
    New-mRNGConnection @Splat
}

# Write-Host "ProdServers : $ProdServers "
# $ProdWebServers = New-mRNGContainer -Name 'WebServers' -Credential $ProdServerCreds -ParentContainer $RxITDSServers -InheritCredential
$csvgdp = Import-Csv -Path '.\ec2_asset_data.csv' | ? uses_autoscaling -like *NO* | ? longcode -like *gdp_* | ? environment -like *ti*
$ServersContainer = New-mRNGContainer -Name 'GDP-TIN' -ParentContainer $RxITDSServers -InheritCredential

foreach ($i in $csvgdp) {
    # Create new connection
	# Write-Host "Many containers ProdWebServers : $i"
    $serverhostname = "unknown"
	if($i.hostname -ne ""){
		$serverhostname = $i.hostname	
	}
	
    $Splat = @{
        Name              = '{0} - {1} - {2}' -f ($i.longcode, $i.InstanceName, $serverhostname)
        Hostname          = $serverhostname
        Protocol          = 'RDP'
        InheritCredential = $true
		ParentContainer   = $ServersContainer
    }
    New-mRNGConnection @Splat
} #>
