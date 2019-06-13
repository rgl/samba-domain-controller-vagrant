$ErrorActionPreference = 'Stop'

@(
    'RSAT-AD-PowerShell'    # Active Directory module for Windows PowerShell
    'RSAT-ADDS-Tools'       # AD DS Snap-Ins and Command-Line Tools
    'RSAT-DNS-Server'       # DNS Server Tools	
    'GPMC'                  # Group Policy Management
) | ForEach-Object {
    Install-WindowsFeature $_
}
