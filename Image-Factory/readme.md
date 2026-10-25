# Hyper-V Image Factory #

This is a PowerShell script that creates and maintains a set of Windows virtual hard disks for me that are always up to date.  

# What is this all about? #

For more information - read here (archived): https://web.archive.org/web/20151112162739/http://blogs.msdn.com/b/virtual_pc_guy/archive/2015/06/16/script-image-factory-for-hyper-v.aspx

The flow is still the one the post describes; the 2026 update changed what it builds and how.

# Requirements #

* A Hyper-V host (Windows Server 2022/2025 or Windows 11), run as administrator
* A virtual switch with Internet access for the factory VM
* ISOs (or install.wim / install.esd) in `ISOs\`, listed in `$Images` in FactoryVariables.ps1
* `$adminPassword` and `$userPassword` set in FactoryVariables.ps1. The final images carry them in plain text in
  `\Windows\Panther\unattend.xml` until the deployed VM's first logon deletes it, so use throwaway passwords.

PSWindowsUpdate is downloaded from the PowerShell Gallery on first run. Convert-WindowsImage is no longer needed.

# Change Log #

10/25/26 -
* Windows Server 2022, Windows Server 2025 and Windows 11 only; everything older (and 32 bit) removed
* Generation 2 only, Secure Boot left on; Windows 11 VMs get a TPM. Fixes the `if($Gen = 2)` assignment from the #36 fix
* Base disk built with New-VHD, Expand-WindowsImage and bcdboot instead of Convert-WindowsImage (TechNet Gallery is gone)
* PSWindowsUpdate from the PowerShell Gallery; updates installed with Install-WindowsUpdate
* Windows 11: device encryption prevented, Store app auto-update blocked during the factory run (it breaks sysprep)
* Timeouts on the VM run and the Internet check (HTTPS instead of ping); one failed image no longer stops the rest
* Empty product keys allowed; editions picked by image name or index (Get-WindowsImage)
* Panther unattend copy removed from the base image and on the deployed VM's first logon
* Checkpoints disabled on the factory VM; transcript written to `Logs\`; ISO 8601 dates in Details.csv
* Images listed in `$Images` in FactoryVariables.ps1 rather than in Factory.ps1

10/30/15 -
* Changes from Garry Martin
  * Add support for Windows 7 and Windows Server 2008 R2 by installing WMF and .NET Framework
  * Add LegacyVHD parameter to allow legacy VHD format files to be created instead of VHDX files
  * Change behaviour for removal of autorun registry key
  * Clean up Temp directory and Demo user if created

8/21/15 -
* Changes from Grant Emsley
  * Support configuration of static IP address on the factory VM
  * Verify product keys have been set

8/17/15 -
* Changes from Grant Emsley
  * Optimize final VHD file
  * Optionally clean the windows component store to save disk space

8/16/15 -

* Changes from Grant Emsley
  * Support for configuring Factory VM RAM and VLAN
  * Better error handling on missing folders / dependancies
  * Better handling of missing ISO / WIM files

8/1/15 -

* Tested with Windows 10 (yay!)
* Moved variables into separate file to make it easier to accept changes - and to stop people from giving me their product keys
* Added code to check for and create directories that are missing

7/29/15 -

* Accepted changes from Christoph Petersen that: 
   * Cleaned up files inside the virtual machine at the end
   * Added support for an external sysprep process
   * Made the code a lot prettier to look at (thanks Christoph!)

# To do #

This is the list of things currently in my "to do" list.  Feel free to tackle any of them yourself and request a pull.

* MD5 summing for virtual hard drives in the share folder
* Make variables for the build and share directories - so they do not have to be under the working directory
* Update this readme to have more information from the blog post - and vice versa
