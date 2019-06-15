$ErrorActionPreference = 'Stop'

# NB Samba has no Active Directory Web Services (ADWS) implementation,
#    so you cannot use Active Directory Administrative Center.
@(
    'RSAT-AD-PowerShell'    # Active Directory module for Windows PowerShell
    'RSAT-ADDS-Tools'       # AD DS Snap-Ins and Command-Line Tools
    'RSAT-DNS-Server'       # DNS Server Tools	
    'GPMC'                  # Group Policy Management
) | ForEach-Object {
    Install-WindowsFeature $_
}
