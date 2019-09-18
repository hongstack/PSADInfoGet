# PSADInfoGet
**PSADInfoGet** is a PowerShell module that provides commands for getting information from active directory.

## Overview
Information in active directory is available but not easy to access, especially when Microsoft Active Directory module is not installed in some corporate environments. 

**PSADInfoGet** aims to provide a set of commands to read active directory and present in a friendly way to non-admin user. It is developed with performance and easy-to-use in mind.

**PSADInfoGet** is _**safe**_ to use and will not cause any careless change to the active directory because it only provides read commands.

## Installation
Clone or download [PSADInfoGet](https://github.com/hongstack/PSADInfoGet/archive/master.zip), decompress it if downloaded, then copy it to: `C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Modules`.

If the [PSLocalModule](https://github.com/hongstack/PSLocalModule) is installed, it only needs to run the following command:
```PowerShell
Set-PSCodePath <parent_dir_to_PSADInfoGet>
Import-LocalModule PSADInfoGet
```

## Usage
Use PowerShell's `Get-Command -Module PSADInfoGet` to explore available commands, and `Get-Help <Cmdlet>` to find out the usage for each command.

## TODO
* Get all users by an AD group
* Add `-Full` flag to Get-ADGroupInfo to get full information for the assigned groups
* Cache search result
* Automatically adjust search limit