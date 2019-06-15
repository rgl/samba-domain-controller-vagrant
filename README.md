# Caveats

* Samba has no Active Directory Web Services (ADWS) implementation. This means that you cannot use anything that uses those services, e.g.:
  * Active Directory Administrative Center.
  * PowerShell cmdlets like [Get-ADDomain](https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-addomain?view=winserver2012-ps).
