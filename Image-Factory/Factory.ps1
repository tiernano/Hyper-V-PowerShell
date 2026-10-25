#Requires -RunAsAdministrator
#Requires -Modules Hyper-V, Dism
# Load variables from a seperate file - this when you pull down the latest factory file you can keep your paths / product keys etc...
. "$PSScriptRoot\FactoryVariables.ps1"
$startTime = get-date


# Helper function to make sure that needed folders are present
function checkPath
{
    param
    (
        [string] $path
    )
    if (!(Test-Path $path))
    {
        $null = md $path;
    }
}

# Test that necessary paths and files exist
# Don't create the workingDir automatically - if it doesn't exist, the variables probably need the be configured first.
if(-not (Test-Path -Path $workingDir -PathType Container)) {
  Throw "Working directory $workingDir does not exist - edit FactoryVariables.ps1 to configure script"
}

if(-not $adminPassword -or -not $userPassword) {
  Throw 'Set $adminPassword and $userPassword in FactoryVariables.ps1'
}

# Create folders in workingDir if they don't exist
checkPath "$($workingdir)\Share"
checkPath "$($workingdir)\Bases"
checkPath "$($workingdir)\ISOs"
checkPath "$($workingdir)\Logs"
checkPath "$($workingdir)\Resources"
checkPath "$($workingdir)\Resources\bits"

# PSWindowsUpdate goes into Bits so the factory VM can load it - fetch it from the PowerShell Gallery if it is missing
if(-not (Get-ChildItem "$($ResourceDirectory)\bits\PSWindowsUpdate" -Recurse -Filter PSWindowsUpdate.psd1 -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor Green "Downloading PSWindowsUpdate to $($ResourceDirectory)\bits"
    Save-Module -Name PSWindowsUpdate -Path "$($ResourceDirectory)\bits" -Repository PSGallery -ErrorAction Stop
}


### Sysprep unattend XML
$unattendSource = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing></servicing>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
            <ProductKey>Key</ProductKey>
            <RegisteredOrganization>Organization</RegisteredOrganization>
            <RegisteredOwner>Owner</RegisteredOwner>
            <TimeZone>TZ</TimeZone>
        </component>
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
             <fDenyTSConnections>false</fDenyTSConnections>
         </component>
         <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
             <UserAuthentication>0</UserAuthentication>
         </component>
         <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
             <FirewallGroups>
                 <FirewallGroup wcm:action="add" wcm:keyValue="RemoteDesktop">
                     <Active>true</Active>
                     <Profile>all</Profile>
                     <Group>@FirewallAPI.dll,-28752</Group>
                 </FirewallGroup>
             </FirewallGroups>
         </component>
         <!-- Windows 11 turns on device encryption when it finds a TPM; an encrypted base disk could not be mounted or compacted -->
         <component name="Microsoft-Windows-SecureStartup-FilterDriver" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
             <PreventDeviceEncryption>true</PreventDeviceEncryption>
         </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>password</Value>
                    <PlainText>True</PlainText>
                </AdministratorPassword>
                <LocalAccounts>
                   <LocalAccount wcm:action="add">
                       <Password>
                           <Value>password</Value>
                           <PlainText>True</PlainText>
                       </Password>
                       <DisplayName>Demo</DisplayName>
                       <Group>Administrators</Group>
                       <Name>demo</Name>
                   </LocalAccount>
               </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
               <Password>
                  <Value>password</Value>
               </Password>
               <Enabled>true</Enabled>
               <LogonCount>1000</LogonCount>
               <Username>Administrator</Username>
            </AutoLogon>
             <LogonCommands>
                 <AsynchronousCommand wcm:action="add">
                     <CommandLine>%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell -NoLogo -NonInteractive -ExecutionPolicy Bypass -File %SystemDrive%\Bits\Logon.ps1</CommandLine>
                     <Order>1</Order>
                 </AsynchronousCommand>
             </LogonCommands>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-us</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-us</UILanguage>
            <UILanguageFallback>en-us</UILanguageFallback>
            <UserLocale>en-us</UserLocale>
        </component>
    </settings>
</unattend>
"@

function CSVLogger {
    param
    (
        [string] $vhd,
        [switch] $sysprepped
    );

    $createLogFile = $false;
    $entryExists = $false;
    $logCsv = @();
    $newEntry = $null;
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm';

    # Check if the log file exists
    if (-not (Test-Path $logFile))
    {
        $createLogFile = $true;
    }
    else
    {
        $logCsv = import-csv $logFile;

        if (($logCsv.Image -eq $null) -or `
            ($logCsv.Created -eq $null) -or `
            ($logCsv.Sysprepped -eq $null) -or `
            ($logCsv.Checked -eq $null))
        {
            # Something is wrong with the log file
            cleanupFile $logFile;
            $createLogFile = $true;
        }
    }

    if ($createLogFile)
    {
        $logCsv = @();
    }

    # If we find an entry for the VHD, update it
    foreach ($entry in $logCsv)
    {
        if ($entry.Image -eq $vhd)
        {
            $entryExists = $true;
            $entry.Checked = $now;

            if ($sysprepped)
            {
                $entry.Sysprepped = $now;
            }
        }
    }

    # if no entry is found, create a new one
    if (-not $entryExists)
    {
        $newEntry = New-Object PSObject -Property @{
            Image = $vhd
            Created = $now
            Sysprepped = $now
            Checked = $now
        };
    }

    # Write out the CSV file
    $logCsv | Export-CSV $logFile -NoTypeInformation;
    if (-not ($newEntry -eq $null))
    {
        $newEntry | Export-CSV $logFile -NoTypeInformation -Append;
    }
}

function Logger {
    param
    (
        [string]$systemName,
        [string]$message
    );

    # Function for displaying formatted log messages.  Also displays time in minutes since the script was started
    write-host (Get-Date).ToShortTimeString() -ForegroundColor Cyan -NoNewline;
    write-host " - [" -ForegroundColor White -NoNewline;
    write-host $systemName -ForegroundColor Yellow -NoNewline;
    write-Host "]::$($message)" -ForegroundColor White;
}

# Helper function for no error file cleanup
function cleanupFile
{
    param
    (
        [string] $file
    )

    if (Test-Path $file)
    {
        Remove-Item $file -Recurse -Force > $null;
    }
}

function GetUnattendChunk
{
    param
    (
        [string] $pass,
        [string] $component,
        [xml] $unattend
    );

    # Helper function that returns one component chunk from the Unattend XML data structure
    return $Unattend.unattend.settings | ? pass -eq $pass `
        | select -ExpandProperty component `
        | ? name -eq $component;
}

function removeUnattendNode
{
    param
    (
        [xml] $unattend,
        [string] $xpath
    );

    $ns = New-Object System.Xml.XmlNamespaceManager($unattend.NameTable);
    $ns.AddNamespace("ns", $unattend.DocumentElement.NamespaceURI);
    $node = $unattend.SelectSingleNode($xpath, $ns);
    $node.ParentNode.RemoveChild($node) | Out-Null;
}

function makeUnattendFile
{
    param
    (
        [string] $key,
        [string] $logonCount,
        [string] $filePath,
        [bool] $desktop = $false
    );

    # Composes unattend file and writes it to the specified filepath

    # Reload template - clone is necessary as PowerShell thinks this is a "complex" object
    $unattend = $unattendSource.Clone();

    # Customize unattend XML
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.RegisteredOrganization = $Organization};
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.RegisteredOwner = $Owner};
    GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.TimeZone = $Timezone};
    GetUnattendChunk "oobeSystem" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.UserAccounts.AdministratorPassword.Value = $adminPassword};
    GetUnattendChunk "oobeSystem" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.AutoLogon.Password.Value = $adminPassword};
    GetUnattendChunk "oobeSystem" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.AutoLogon.LogonCount = $logonCount};

    # No key (evaluation media, or activating later) - leave the element out rather than sending an empty one
    if ($key)
    {
        GetUnattendChunk "specialize" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.ProductKey = $key};
    }
    else
    {
        removeUnattendNode $unattend "//ns:ProductKey";
    }

    if ($desktop)
    {
        # Windows 11 needs a user other than "Administrator" to be present, and HideLocalAccountScreen is server only
        GetUnattendChunk "oobeSystem" "Microsoft-Windows-Shell-Setup" $unattend | %{$_.UserAccounts.LocalAccounts.LocalAccount.Password.Value = $userPassword};
        removeUnattendNode $unattend "//ns:HideLocalAccountScreen";
    }
    else
    {
        # Servers need neither the extra user nor the device encryption setting (client only)
        removeUnattendNode $unattend "//ns:LocalAccounts";
        removeUnattendNode $unattend "//ns:component[@name='Microsoft-Windows-SecureStartup-FilterDriver']";
    }

    # Write it out to disk
    cleanupFile $filePath; $Unattend.Save($filePath);
}

function createRunAndWaitVM
{
    param
    (
        [string] $vhd,
        [bool] $desktop = $false
    );

    # Function for whenever I have a VHD that is ready to run
    # Generation 2 with Secure Boot on (the MicrosoftWindows template is the Gen 2 default)
    New-VM $factoryVMName -MemoryStartupBytes $VMMemory -VHDPath $vhd -Generation 2 -SwitchName $virtualSwitchName -ErrorAction Stop | Out-Null

    If($UseVLAN) {
        Get-VMNetworkAdapter -VMName $factoryVMName | Set-VMNetworkAdapterVlan -Access -VlanId $VlanId
    }

    # Windows 11 requires a TPM. The VM is thrown away after each run, so a local key protector is fine.
    if ($desktop)
    {
        Set-VMKeyProtector -VMName $factoryVMName -NewLocalKeyProtector;
        Enable-VMTPM -VMName $factoryVMName;
    }

    # No checkpoints: client Hyper-V takes one on start by default, which would leave an .avhdx on top of our disk
    Set-VM -Name $factoryVMName -ProcessorCount $VMProcessorCount -CheckpointType Disabled;
    Start-VM $factoryVMName;

    # Give the VM a moment to start before we start checking for it to stop
    Start-Sleep -Seconds 10;

    # Wait for the VM to be stopped for a good solid 5 seconds
    $deadline = (Get-Date).AddMinutes($VMTimeoutMinutes);
    do
    {
        if ((Get-Date) -gt $deadline)
        {
            Stop-VM $factoryVMName -TurnOff -Force;
            Remove-VM $factoryVMName -Force;
            throw "Factory VM still running after $VMTimeoutMinutes minutes (a failed sysprep leaves it sitting at the desktop - see \Windows\System32\Sysprep\Panther\setupact.log on the disk)";
        }

        $state1 = (Get-VM -Name $factoryVMName).State;
        Start-Sleep -Seconds 5;

        $state2 = (Get-VM -Name $factoryVMName).State;
        Start-Sleep -Seconds 5;
    }
    until (($state1 -eq "Off") -and ($state2 -eq "Off"))

    # Clean up the VM
    Remove-VM $factoryVMName -Force;
}

function MountVHDandRunBlock
{
    param
    (
        [string]$vhd,
        [scriptblock]$block,
        [switch]$ReadOnly
    );

    # This function mounts a VHD, runs a script block and unmounts the VHD.
    # Drive letter of the mounted VHD is stored in $driveLetter - can be used by script blocks
    # Only the Windows (NTFS) volume gets a letter; the EFI and MSR partitions do not.
    $driveLetter = (Mount-VHD $vhd -ReadOnly:$ReadOnly -Passthru | Get-Disk | Get-Partition | Get-Volume |
        Where-Object { $_.DriveLetter -and $_.FileSystem -eq 'NTFS' } | Select-Object -First 1).DriveLetter;
    try
    {
        & $block;
    }
    finally
    {
        Dismount-VHD $vhd;

        # Wait 2 seconds for activity to clean up
        Start-Sleep -Seconds 2;
    }
}

function New-BaseVHD
{
    param
    (
        [string] $ISOFile,
        [string] $SKUEdition,
        [string] $vhd,
        [string] $unattendPath
    );

    # Replaces Convert-WindowsImage: GPT disk with EFI, MSR and Windows partitions, image applied with DISM, made bootable with bcdboot
    $iso = $null;
    if ($ISOFile -like '*.iso')
    {
        $iso = Mount-DiskImage -ImagePath $ISOFile -PassThru;
        $isoDrive = ($iso | Get-Volume).DriveLetter;
        $image = Get-Item "$($isoDrive):\sources\install.wim", "$($isoDrive):\sources\install.esd" -ErrorAction SilentlyContinue | Select-Object -First 1;
    }
    else
    {
        $image = Get-Item $ISOFile;
    }

    try
    {
        if (-not $image) { throw "No install.wim or install.esd in $ISOFile" }
        if ($SKUEdition -match '^\d+$') { $edition = @{ Index = [int]$SKUEdition } } else { $edition = @{ Name = $SKUEdition } }

        New-VHD -Path $vhd -SizeBytes 80GB -Dynamic | Out-Null;
        $disk = Mount-VHD $vhd -Passthru | Get-Disk;
        try
        {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT;

            # Create the EFI partition as a data partition so it can be formatted, then change its type (as Convert-WindowsImage does)
            $efi = New-Partition -DiskNumber $disk.Number -Size 260MB -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}';
            Format-Volume -Partition $efi -FileSystem FAT32 -Force -Confirm:$false | Out-Null;
            $efi | Set-Partition -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}';
            $efi | Add-PartitionAccessPath -AssignDriveLetter;
            $efiDrive = ($efi | Get-Partition).DriveLetter;

            New-Partition -DiskNumber $disk.Number -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' | Out-Null;

            $windows = New-Partition -DiskNumber $disk.Number -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}';
            Format-Volume -Partition $windows -FileSystem NTFS -Force -Confirm:$false | Out-Null;
            $windows | Add-PartitionAccessPath -AssignDriveLetter;
            $windowsDrive = ($windows | Get-Partition).DriveLetter;

            Expand-WindowsImage -ImagePath $image.FullName -ApplyPath "$($windowsDrive):\" @edition -ErrorAction Stop | Out-Null;
            & bcdboot.exe "$($windowsDrive):\Windows" /s "$($efiDrive):" /f UEFI | Out-Null;
            if ($LASTEXITCODE -ne 0) { throw "bcdboot failed with exit code $LASTEXITCODE" }

            # Setup picks this up on first boot
            checkPath "$($windowsDrive):\Windows\Panther";
            Copy-Item $unattendPath "$($windowsDrive):\Windows\Panther\unattend.xml";

            $efi | Remove-PartitionAccessPath -AccessPath "$($efiDrive):\";
        }
        finally
        {
            Dismount-VHD $vhd;
        }
    }
    catch
    {
        cleanupFile $vhd;
        throw;
    }
    finally
    {
        if ($iso) { Dismount-DiskImage -ImagePath $ISOFile | Out-Null }
    }
}

### Update script block
$updateCheckScriptBlock = {
    function Logger {
        param
        (
            [string]$message
        );

        # Function for displaying formatted log messages.  Also displays time in minutes since the script was started
        write-host (Get-Date).ToShortTimeString() -ForegroundColor Cyan -NoNewline;
        write-host " - ::$($message)" -ForegroundColor White;
    }

    # Clean up unattend files if they are there - the Panther copy holds the admin password in plain text
    Remove-Item "$ENV:SystemDrive\Unattend.xml", "$ENV:SystemRoot\Panther\unattend.xml" -Force -ErrorAction SilentlyContinue

    # Stop the Store updating apps for this user: sysprep fails on apps installed for a user but not provisioned.
    # Removed again by the post-sysprep script on the deployed VM.
    New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore -Force | Out-Null
    Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore -Name AutoDownload -Value 2 -Type DWord

    # Files copied from a downloaded zip may be blocked
    Get-ChildItem $env:SystemDrive\Bits -Recurse | Unblock-File
    Import-Module (Get-ChildItem $env:SystemDrive\Bits\PSWindowsUpdate -Recurse -Filter PSWindowsUpdate.psd1 | Select-Object -First 1).FullName

    # Set static IP address - do not change values here, change them in FactoryVariables.ps1
    $UseStaticIP = STATICIPBOOLPLACEHOLDER
    if($UseStaticIP) {
        $IP = 'IPADDRESSPLACEHOLDER'
        $MaskBits = 'SUBNETMASKPLACEHOLDER'
        $Gateway = 'GATEWAYPLACEHOLDER'
        $DNS = 'DNSPLACEHOLDER'
        $IPType = 'IPTYPEPLACEHOLDER'

        $adapter = Get-NetAdapter | Where-Object {$_.Status -eq 'up'}
        # Remove any existing IP, gateway from our ipv4 adapter
        If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
            $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
        }
        If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
            $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
        }
        # Configure the IP address and default gateway
        $adapter | New-NetIPAddress -AddressFamily $IPType `
            -IPAddress $IP `
            -PrefixLength $MaskBits `
            -DefaultGateway $Gateway
        # Configure the DNS client server IP addresses
        $adapter | Set-DnsClientServerAddress -ServerAddresses $DNS
    }

    # Wait for the network - HTTPS rather than ping, which many networks drop. Give up after 10 minutes.
    logger "Checking for Internet connection"
    $deadline = (Get-Date).AddMinutes(10)
    while (-not (Test-NetConnection -ComputerName www.microsoft.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue))
    {
        if ((Get-Date) -gt $deadline)
        {
            New-Item $env:SystemDrive\Bits\noInternet.txt -type file -Force > $null
            Stop-Computer -Force
            return
        }
        Start-Sleep -Seconds 5
        logger "Checking for Internet connection"
    }

    # Run pre-update script if it exists
    if (Test-Path "$env:SystemDrive\Bits\PreUpdateScript.ps1") {
        & "$env:SystemDrive\Bits\PreUpdateScript.ps1"
    }

    # Check if any updates are needed - leave a marker if there are
    logger "Checking for updates"
    if ((Get-WindowsUpdate -NotCategory "Language packs" -IgnoreUserInput).Count -gt 0)
    {
        New-Item $env:SystemDrive\Bits\changesMade.txt -type file -Force > $null
    }

    # Apply all the updates
    logger "Applying the updates"
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -IgnoreUserInput -NotCategory "Language packs"

    # Run post-update script if it exists
    if (Test-Path "$env:SystemDrive\Bits\PostUpdateScript.ps1") {
        & "$env:SystemDrive\Bits\PostUpdateScript.ps1"
    }

    # Remove static IP address
    if($UseStaticIP) {
        $adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
        $interface = $adapter | Get-NetIPInterface -AddressFamily $IPType

        If ($interface.Dhcp -eq "Disabled") {
            If (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
                $interface | Remove-NetRoute -Confirm:$false
            }
            $interface | Set-NetIPInterface -DHCP Enabled
            $interface | Set-DnsClientServerAddress -ResetServerAddresses
        }
    }

    # Reboot if needed - otherwise shutdown because we are done
    if (Get-WURebootStatus -Silent)
    {
        Restart-Computer -Force
    }
    else
    {
        Stop-Computer -Force
    }
};

function Set-UpdateCheckPlaceHolders {
    $block = $updateCheckScriptBlock | Out-String -Width 4096

    if($UseStaticIP) {
        $block = $block.Replace('$UseStaticIP = STATICIPBOOLPLACEHOLDER', '$UseStaticIP = $true')
        $block = $block.Replace('IPADDRESSPLACEHOLDER', $IP)
        $block = $block.Replace('SUBNETMASKPLACEHOLDER', $MaskBits)
        $block = $block.Replace('GATEWAYPLACEHOLDER', $Gateway)
        $block = $block.Replace('DNSPLACEHOLDER', $DNS)
        $block = $block.Replace('IPTYPEPLACEHOLDER', $IPType)
    } else {
        $block = $block.Replace('$UseStaticIP = STATICIPBOOLPLACEHOLDER', '$UseStaticIP = $false')
    }
    return $block
}

### Sysprep script block
$sysprepScriptBlock = {
    # Run pre-sysprep script if it exists
    if (Test-Path "$env:SystemDrive\Bits\PreSysprepScript.ps1") {
        & "$env:SystemDrive\Bits\PreSysprepScript.ps1"
    }

    # Remove Unattend entries from the autorun key if they exist
    $run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    (Get-Item $run).Property | ? { $_ -like 'Unattend*' } | % { Remove-ItemProperty -Path $run -Name $_ }

    $unattendedXmlPath = "$ENV:SystemDrive\Bits\Unattend.xml";
    & "$ENV:SystemRoot\System32\Sysprep\Sysprep.exe" `/generalize `/oobe `/shutdown `/unattend:"$unattendedXmlPath";
};

### Post Sysprep script block - runs at the first logon of a VM deployed from the final image
$postSysprepScriptBlock = {
    # Remove Unattend entries from the autorun key if they exist
    $run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    (Get-Item $run).Property | ? { $_ -like 'Unattend*' } | % { Remove-ItemProperty -Path $run -Name $_ }

    # Run post-sysprep script if it exists
    if (Test-Path "$env:SystemDrive\Bits\PostSysprepScript.ps1") {
        & "$env:SystemDrive\Bits\PostSysprepScript.ps1"
    }

    # Clean up unattend files (Panther keeps a copy with the passwords in plain text), bits and temp
    Remove-Item "$ENV:SystemDrive\Unattend.xml", "$ENV:SystemRoot\Panther\unattend.xml", "$ENV:SystemDrive\Bits", "$ENV:SystemDrive\Temp" `
        -Force -Recurse -ErrorAction SilentlyContinue

    # Undo the factory's Store policy
    Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore -Name AutoDownload -ErrorAction SilentlyContinue

    # Remove Demo user
    Remove-LocalUser -Name demo -ErrorAction SilentlyContinue

    # Put any code you want to run Post sysprep here
    Restart-Computer -Force
};

# This is the main function of this script
function Start-ImageFactory
{
	<#
			.SYNOPSIS
			Creates or updates a windows image with the latest windows updates.

            .DESCRIPTION
            This function creates fully updated VHDX images for deployment as Generation 2 virtual machines.

            The first time it is called for a particular windows type, it creates a fresh install in a Hyper-V virtual machine,
            updates it, and saves a sysprepped image. The unsysprepped VHDX is kept so future runs only need to install new updates.

            Much of the configuration is done in FactoryVariables.ps1, which must be edited to suit your environment.

			.PARAMETER FriendlyName
			Used as the file name for the image.

            .PARAMETER ISOFile
            The ISO, install.wim or install.esd file to use as the base of the windows image.

            .PARAMETER SKUEdition
            The name or index number of the edition to use from the image (see Get-WindowsImage).
            eg. "Windows 11 Pro" or "Windows Server 2025 Datacenter (Desktop Experience)"

            .PARAMETER ProductKey
            The product key to use for the unattended installation. Leave empty for evaluation media.

            .PARAMETER Desktop
            Set to $true for Windows 11. Adds a TPM to the factory VM and creates the regular user account the client OOBE needs.

            .PARAMETER GenericSysprep
            Run the final sysprep without specifying a /unattend file.  This is required by some deployment tools like SCVMM which will run their own sysprep when deploying.

            .NOTES
            PSWindowsUpdate is downloaded from the PowerShell Gallery on first run.

			.LINK
            https://github.com/tiernano/Hyper-V-PowerShell

            .EXAMPLE
            Start-ImageFactory -FriendlyName "Windows Server 2025 Datacenter Core" -ISOFile c:\path\to\isos\server2025.iso -SKUEdition "Windows Server 2025 Datacenter"

            .EXAMPLE
            Start-ImageFactory -FriendlyName "Windows 11 Pro" -ISOFile c:\path\to\isos\windows11.iso -SKUEdition "Windows 11 Pro" -Desktop $true

	#>


    param
    (
        [Parameter(Mandatory=$true)][string]$FriendlyName,
        [string]$ISOFile,
        [string]$ProductKey,
        [string]$SKUEdition,
        [bool]$desktop = $false,
        [bool] $GenericSysprep = $false
    );

    logger $FriendlyName "Starting a new cycle!"

    # Setup a bunch of variables
    $sysprepNeeded = $true;

    $baseVHD = "$($workingDir)\bases\$($FriendlyName)-base.vhdx";
    $updateVHD = "$($workingDir)\$($FriendlyName)-update.vhdx";
    $sysprepVHD = "$($workingDir)\$($FriendlyName)-sysprep.vhdx";
    $finalVHD = "$($workingDir)\share\$($FriendlyName).vhdx";

    # Verify product key
    if($ProductKey -and -not ($ProductKey -imatch '^[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}$')) {
        logger $FriendlyName 'Invalid product key, skipping this product'
        return
    }

    logger $FriendlyName "Checking for existing Factory VM";

    # Check if there is already a factory VM - and kill it if there is
    if (Get-VM -Name $factoryVMName -ErrorAction SilentlyContinue)
    {
        Stop-VM $factoryVMName -TurnOff -Force -Passthru | Remove-VM -Force;
    }

    # Check for a base VHD
    if (-not (test-path $baseVHD))
    {
        if (-not (Test-Path $ISOFile)) {
            logger $FriendlyName 'ISO/WIM file missing, skipping this product.'
            return
        }

        # No base VHD - we need to create one
        logger $FriendlyName "No base VHD!";

        # Make unattend file
        logger $FriendlyName "Creating unattend file for base VHD";

        # Logon count is just "large number"
        makeUnattendFile -key $ProductKey -logonCount "1000" -filePath "$($workingDir)\unattend.xml" -desktop $desktop;

        # Time to create the base VHD
        logger $FriendlyName "Create base VHD from $ISOFile";
        try
        {
            New-BaseVHD -ISOFile $ISOFile -SKUEdition $SKUEdition -vhd $baseVHD -unattendPath "$($workingDir)\unattend.xml";
        }
        finally
        {
            # Clean up unattend file - we don't need it any more
            logger $FriendlyName "Remove unattend file now that that is done";
            cleanupFile "$($workingDir)\unattend.xml";
        }

        logger $FriendlyName "Mount VHD and copy bits in, also set startup file";
        MountVHDandRunBlock $baseVHD {
            # Copy bits to VHD
            Copy-Item "$($ResourceDirectory)\bits" -Destination ($driveLetter + ":\") -Recurse;

            # Create first logon script
            Set-UpdateCheckPlaceHolders | Out-File -FilePath "$($driveLetter):\Bits\Logon.ps1" -Width 4096;
        }

        logger $FriendlyName "Create virtual machine, start it and wait for it to stop...";
        createRunAndWaitVM $baseVHD $desktop;

        # Remove Page file
        logger $FriendlyName "Removing the page file";
        MountVHDandRunBlock $baseVHD {
            attrib -s -h "$($driveLetter):\pagefile.sys";
            cleanupFile "$($driveLetter):\pagefile.sys";
        }

        # Compact the base file
        logger $FriendlyName "Compacting the base file";
        Optimize-VHD -Path $baseVHD -Mode Full;
    }
    else
    {
        # The base VHD existed - time to check if it needs an update
        logger $FriendlyName "Base VHD exists - need to check for updates";

        # create new diff to check for updates
        logger $FriendlyName "Create new differencing disk to check for updates";
        cleanupFile $updateVHD;
        New-VHD -Path $updateVHD -ParentPath $baseVHD | Out-Null;

        logger $FriendlyName "Copy login file for update check, also make sure flag file is cleared"
        MountVHDandRunBlock $updateVHD {
            # Refresh the Bits folder
            cleanupFile "$($driveLetter):\Bits"
            Copy-Item "$($ResourceDirectory)\bits" -Destination ($driveLetter + ":\") -Recurse;
            # Create the update check logon script
            Set-UpdateCheckPlaceHolders | Out-File -FilePath "$($driveLetter):\Bits\Logon.ps1" -Width 4096;
        }

        logger $FriendlyName "Create virtual machine, start it and wait for it to stop...";
        createRunAndWaitVM $updateVHD $desktop;

        # Check to see if changes were made
        logger $FriendlyName "Check to see if there were any updates";
        $sysprepNeeded = MountVHDandRunBlock $updateVHD {
            if (Test-Path "$($driveLetter):\Bits\noInternet.txt")
            {
                logger $FriendlyName "WARNING: the factory VM had no Internet access - no updates were checked";
            }

            if (Test-Path "$($driveLetter):\Bits\changesMade.txt")
            {
                cleanupFile "$($driveLetter):\Bits\changesMade.txt";
                logger $FriendlyName "Updates were found";
                $true
            }
            else
            {
                logger $FriendlyName "No updates were found";
                $false
            }
        }

        # If changes were made - merge them in.  If not, throw it away
        if ($sysprepNeeded)
        {
            logger $FriendlyName "Merge the differencing disk";
            Merge-VHD -Path $updateVHD -DestinationPath $baseVHD;
        }
        else
        {
            logger $FriendlyName "Delete the differencing disk";
            CSVLogger $finalVHD;
            cleanupFile $updateVHD;
        }
    }

    # Final Check - if the final VHD is missing - we need to sysprep and make it
    if (-not (Test-Path $finalVHD))
    {
        $sysprepNeeded = $true;
    }

    if ($sysprepNeeded)
    {
        # create new diff to sysprep
        logger $FriendlyName "Need to run Sysprep";
        logger $FriendlyName "Creating differencing disk";
        cleanupFile $sysprepVHD; new-vhd -Path $sysprepVHD -ParentPath $baseVHD | Out-Null;

        logger $FriendlyName "Mount the differencing disk and copy in files";
        MountVHDandRunBlock $sysprepVHD {
            $sysprepScriptBlockString = $sysprepScriptBlock | Out-String;

            if($GenericSysprep)
            {
                $sysprepScriptBlockString = $sysprepScriptBlockString.Replace(' `/unattend:"$unattendedXmlPath"', "");
            }
            else
            {
                # Make unattend file
                makeUnattendFile -key $ProductKey -logonCount "1" -filePath "$($driveLetter):\Bits\unattend.xml" -desktop $desktop;
            }

            # Make the logon script
            cleanupFile "$($driveLetter):\Bits\Logon.ps1";
            $sysprepScriptBlockString | Out-File -FilePath "$($driveLetter):\Bits\Logon.ps1" -Width 4096;
        }

        logger $FriendlyName "Create virtual machine, start it and wait for it to stop...";
        createRunAndWaitVM $sysprepVHD $desktop;

        logger $FriendlyName "Mount the differencing disk and cleanup files";
        MountVHDandRunBlock $sysprepVHD {
            cleanupFile "$($driveLetter):\Bits\unattend.xml";
            cleanupFile "$($driveLetter):\Bits\Logon.ps1";

            if(-not $GenericSysprep)
            {
                # Make the logon script
                $postSysprepScriptBlock | Out-String | Out-File -FilePath "$($driveLetter):\Bits\Logon.ps1" -Width 4096;
            }
            else
            {
                # Cleanup \Bits as the postSysprepScriptBlock is not run anymore
                cleanupFile "$($driveLetter):\Bits";
            }

            # Remove Page file
            attrib -s -h "$($driveLetter):\pagefile.sys";
            cleanupFile "$($driveLetter):\pagefile.sys";
        }

        # Produce the final disk
        cleanupFile $finalVHD;
        logger $FriendlyName "Convert differencing disk into pristine base image";
        Convert-VHD -Path $sysprepVHD -DestinationPath $finalVHD -VHDType Dynamic;
        if($CleanWinSXS) {
            logger $FriendlyName "Cleaning windows component store. Be patient, this may take awhile."
            MountVHDandRunBlock $finalVHD {
                # Clean up the WinSXS store, and remove any superceded components. Updates will no longer be able to be uninstalled,
                # but saves a considerable amount of disk space.
                dism.exe /image:$($driveLetter):\ /Cleanup-Image /StartComponentCleanup /ResetBase
            }
        }
        logger $FriendlyName "Optimizing VHD file"
        # Mounting the VHD read only allows it to be compacted better.
        # Running Optimize-VHD twice seems to be necessary - don't know why, but it works.
        MountVHDandRunBlock -ReadOnly $finalVHD {
            Optimize-VHD $finalVHD -Mode Full
            Optimize-VHD $finalVHD -Mode Full
        }
        logger $FriendlyName "Delete differencing disk";
        CSVLogger $finalVHD -sysprepped;
        cleanupFile $sysprepVHD;
    }
}

if($startfactory) {
    Start-Transcript -Path "$($workingDir)\Logs\Factory-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log" | Out-Null

    # One failed image (eg. a sysprep that timed out) should not stop the rest
    foreach ($image in $Images) {
        try {
            Start-ImageFactory @image
        } catch {
            logger $image.FriendlyName "FAILED: $_"
        }
    }

    logger "Factory" "Finished in $([int]((Get-Date) - $startTime).TotalMinutes) minutes"
    Stop-Transcript | Out-Null
} else {
    If($myinvocation.InvocationName -eq '.') {
        Write-Host 'Start-ImageFactory is ready to use'
    } else {
        Write-Host 'Image Factory is set to be dot sourced.  If you want to run this script directly, changed $startfactory to $true in FactoryVariables.ps1'
    }
}
