function Write-Title($title) {
    Write-Output "`n#`n# $title`n#"
}


Write-Title 'NTP status: w32tm /query /status'
w32tm /query /status

Write-Title 'Get-WmiObject Win32_ComputerSystem'
Get-WmiObject Win32_ComputerSystem | Select-Object Name,Domain

Write-Title 'Get-ADDomainController -Discover'
Get-ADDomainController -Discover

Write-Title 'gpresult /z'
gpresult /z

# NB Samba does not implement the Active Directory Web Services (ADWS),
#    so you cannot use cmdlets like Get-ADDomain.
#Write-Title 'Computer Domain:'
#Get-ADDomain -Current LocalComputer
