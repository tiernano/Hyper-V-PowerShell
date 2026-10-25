# Seperate file for variables - this when you pull down the latest factory file you can keep your paths / product keys etc...
$workingDir = "C:\FactoryTest"
$logFile = "$($workingDir)\Share\Details.csv"
$ResourceDirectory = "$($workingDir)\Resources"
$Organization = "The Power Elite"
$Owner = "Ben Armstrong"
$Timezone = "GMT Standard Time"

# Must be set before the first run. These end up in plain text in the unattend file inside every image in Share,
# until the deployed VM's first logon deletes it - so use a throwaway password and change it after deployment.
$adminPassword = ""
$userPassword = ""

# VM Settings
    # Name of the VM - make sure this does not conflict with any existing virtual machine, because it gets deleted automatically!
    $factoryVMName = "Factory VM"

    # Amount of memory and CPUs to give the VM - Windows 11 needs at least 4GB and 2 CPUs
    $VMMemory = 4096mb
    $VMProcessorCount = 2

    # Give up on a VM run (update or sysprep) after this many minutes - a hung sysprep otherwise waits forever
    $VMTimeoutMinutes = 240

    # Virtual switch to connect to - needs internet access to download updates
    $virtualSwitchName = "Virtual Switch"

    # Set to $true and specify VLAN id to connect the VM to a specific VLAN
    $UseVLAN = $false
    $VlanId = 1

    # Enable to use a static IP address for the VM.  Default is to use DHCP
    $UseStaticIP = $false
    $IP = '10.10.10.10'
    $MaskBits = 24
    $Gateway = '10.10.10.1'
    $Dns = '10.10.10.2'
    $IPType = 'IPv4'

# Images to build. ISOFile is an ISO, or an install.wim / install.esd.
# SKUEdition is the image name or index; list them with:
#   Get-WindowsImage -ImagePath D:\sources\install.wim   (mount the ISO first; install.esd on consumer media)
# Evaluation ISOs use different names, eg. "Windows Server 2025 Datacenter Evaluation (Desktop Experience)".
# ProductKey can be left empty (evaluation media, or activate later). The KMS client keys (GVLKs) are published at
#   https://learn.microsoft.com/windows-server/get-started/kms-client-activation-keys
$Images = @(
    @{ FriendlyName = "Windows Server 2025 Datacenter Core";   ISOFile = "$($workingDir)\ISOs\WindowsServer2025.iso"; SKUEdition = "Windows Server 2025 Datacenter";                        ProductKey = "" }
    @{ FriendlyName = "Windows Server 2025 Datacenter";        ISOFile = "$($workingDir)\ISOs\WindowsServer2025.iso"; SKUEdition = "Windows Server 2025 Datacenter (Desktop Experience)"; ProductKey = "" }
    @{ FriendlyName = "Windows Server 2022 Datacenter Core";   ISOFile = "$($workingDir)\ISOs\WindowsServer2022.iso"; SKUEdition = "Windows Server 2022 Datacenter";                        ProductKey = "" }
    @{ FriendlyName = "Windows Server 2022 Datacenter";        ISOFile = "$($workingDir)\ISOs\WindowsServer2022.iso"; SKUEdition = "Windows Server 2022 Datacenter (Desktop Experience)"; ProductKey = "" }
    @{ FriendlyName = "Windows 11 Pro";                        ISOFile = "$($workingDir)\ISOs\Windows11.iso";         SKUEdition = "Windows 11 Pro";                                        ProductKey = ""; Desktop = $true }
)

# Misc Settings
# If $startfactory is false, just import the functions to use in other scripts.  If true, start image generation.
$StartFactory = $true

# If enabled, will use dism.exe to clean the WinSXS folder and remove old updates. This can give significant disk savings, but takes longer (20-30 minutes per image). Updates will not be able to be uninstalled if this is enabled.
$CleanWinSXS = $false
