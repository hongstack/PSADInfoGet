using module .\Classes\ADUserInfo.psm1
using module .\Classes\ADGroupInfo.psm1
using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
Configures the information that affects the active directory searches.

.DESCRIPTION
The Set-ADInfoConfig sets information that is used during search. They are aimed to either 
improve the search performance or maximize the flexibilities.

Note that this function does not make any change to the active directory. The change is 
saved locally.

.PARAMETER UserSearchRoot
Specifies the search root for searching user information.

.PARAMETER GroupSearchRoot
Specifies the search root for searching group information.
#>
function Set-ADInfoConfig {
    [CmdletBinding()]
    Param(
        [Parameter()][String]$UserSearchRoot,
        [Parameter()][String]$GroupSearchRoot
    )

    if ([String]::IsNullOrEmpty($UserSearchRoot) -and [String]::IsNullOrEmpty($GroupSearchRoot)) {
        $PSCmdlet.ThrowTerminatingError(
            [ErrorRecord]::new(
                [PSArgumentException]"No configuration item specified",
                'PSADInfoGet.Set-ADInfoConfig',
                [ErrorCategory]::InvalidArgument,
                $null
            )
        )
    }

    $ModuleConfigPath = $PSCommandPath -replace 'psm1', 'json'
    $ModuleConfigName = $ModuleConfigPath | Split-Path -Leaf
    if (Test-Path -Path $ModuleConfigPath) {
        $ModuleConfig = Get-Content -Path $ModuleConfigPath -Raw | ConvertFrom-Json
        Write-Verbose "Update module configuration: $ModuleConfigName"
    } else {
        $ModuleConfig = [PSCustomObject]@{}
        Write-Verbose "Create module configuration: $ModuleConfigName"
    }

    Add-SearchRootConfig $ModuleConfig 'ADUserInfo'  $UserSearchRoot
    Add-SearchRootConfig $ModuleConfig 'ADGroupInfo' $GroupSearchRoot
    $ModuleConfig | ConvertTo-Json | Set-Content $ModuleConfigPath
}

<#
.SYNOPSIS
Returns the information that is set via Set-ADInfoConfig function.

.DESCRIPTION
The Get-ADInfoConfig returns the information that is set via Set-ADInfoConfig function.
The $null value is returned if the specified variable is not set, or the configuration
does not exist at all.
#>
function Get-ADInfoConfig {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet('UserSearchRoot', 'GroupSearchroot')]
        [String]$Item
    )

    $ModuleConfigPath = $PSCommandPath -replace 'psm1', 'json'
    if (!(Test-Path -Path $ModuleConfigPath)) {
        return $null
    }

    $ModuleConfig = Get-Content -Path $ModuleConfigPath -Raw | ConvertFrom-Json
    switch ($Item) {
        'UserSearchRoot'  { $ModuleConfig.ADUserInfo.SearchRoot; Break }
        'GroupSearchroot' { $ModuleConfig.ADGroupInfo.SearchRoot; Break }
    }
}

function Add-SearchRootConfig($ModuleConfig, $ConfigItem, $ConfigValue) {
    if ($ConfigValue) {
        if ($ModuleConfig.$ConfigItem) {
            $ModuleConfig.$ConfigItem.SearchRoot = $ConfigValue
        } else {
            $ModuleConfig | Add-Member -NotePropertyMembers @{
                $ConfigItem = @{ SearchRoot = $ConfigValue }
            }
        }
    }
}

############################################################
# Functions Import
############################################################

"$PSScriptRoot\Functions\*.ps1" | Resolve-Path |
Where-Object {-not ($_.ProviderPath.ToLower().Contains(".tests."))} |
ForEach-Object { . $_.ProviderPath }