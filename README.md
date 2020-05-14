# PSADInfoGet
**PSADInfoGet** is a PowerShell module that provides commands for getting information from active directory.

## Overview
Information in active directory is available but not easy to access, especially when Microsoft Active Directory module is not installed in some corporate environments. 

**PSADInfoGet** aims to provide a set of commands to read active directory and present in a friendly way to non-admin user. It is developed with performance and easy-to-use in mind.

**PSADInfoGet** is _**safe**_ to use and will not cause any careless change to the active directory because it only provides read commands.

## Installation
### Direct Download
Download [PSADInfoGet v1.1.0](https://github.com/hongstack/PSADInfoGet/releases/download/1.1.0/PSADInfoGet_1.1.0.zip), extracts the content under one of the following locations:
* `C:\Program Files\WindowsPowerShell\Modules` (*applies to all users, but may not be an option in some corporate environments*).
* `$env:USERPROFILE\Documents\WindowsPowerShell\Modules` (*applies to current user*).

### Manual Build
This option assumes [PSLocalModule](https://github.com/hongstack/PSLocalModule) is installed and configured.

When clone to any directory:
```PowerShell
git clone https://github.com/hongstack/PSADInfoGet.git
Set-Location PSADInfoGet
Install-LocalModule -Verbose -Whatif
Install-LocalModule
```

When clone to the `PSCodePath`:
```PowerShell
git clone https://github.com/hongstack/PSADInfoGet.git <PSCodePath>
Install-LocalModule PSADInfoGet -Verbose -Whatif
Install-LocalModule PSADInfoGet
```

## Usage
Use PowerShell's `Get-Command -Module PSADInfoGet` to explore available commands, and `Get-Help <Cmdlet>` to find out the usage for each command.