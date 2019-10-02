using module .\Classes\ADUserInfo.psm1
using module .\Classes\ADGroupInfo.psm1
using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
Gets one or more Active Directory users.

.DESCRIPTION
The Get-ADUserInfo searches Active Directory for user information based on the specified paramters.

All the search parameters (UserId, Name, FirstName and LastName) accepts the wildcards. 
However, the more specific the parameter is, the better the search performs.
- *    : Matches zero or more characters
- ?    : Matches any character
- [ac] : Matches 'a' or 'c'
- [a-c]: Matches 'a', 'b', 'c'

.PARAMETER UserId
Specifies the user id that is evaluated against either samAccountName or employeeID. 
It defaults to the current logon user if not specified. It aliases to:
- sAMAccountName
- EmployeeID
- LogonId

.PARAMETER Name
Specifies the common name (CN) of an active directory entry. It requires minimum of 4 characters. 
It aliases to:
- CN
- FullName

.PARAMETER FirstName
Specifies the given name (GivenName) of an active directory entry. It requires minimum of 2 characters. 
It aliases to:
- GivenName

.PARAMETER LastName
Specifies the surname (SN) of an active directory entry. It requires minimum of 2 characters. 
It aliases to:
- SN
- Surname

.PARAMETER Limit
Specifies the maximum number of results to return, default to 20.

.PARAMETER Properties
Specifies extra active directory properties to search. Specify properties for this parameter as a 
comma-separated list of names. To display all of the properties that are set on the object, specify * (asterisk).

.NOTES
For how to use active directory search with PowerShell
- https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ff730967%28v%3dtechnet.10%29
- https://docs.microsoft.com/en-us/windows/win32/adsi/active-directory-service-interfaces-adsi
- https://docs.microsoft.com/en-us/windows/win32/ad/user-object-attributes
- http://www.informit.com/articles/article.aspx?p=101405&seqNum=7

For APIs on DirectorySearcher and DirectoryEntry
- https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.directorysearcher
- https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.directoryentry

.Example
Get-ADUserInfo

Gets the information for current logon user.

.Example
Get-ADUserInfo -Name *Smith*

Gets the information for all users with 'Smith' in their common name.

.Example
Get-ADUserInfo -FirstName Alex -Limit 10

Gets the information for all users with the first name as 'Alex' and only fetches 10 records.

.Example
Get-ADUserInfo -LastName Samuel -Properties personalTitle, memberOf

Gets the information for all users with the last name as 'Samuel' and fetches additional 
information: personalTitle and memberOf.
#>
function Get-ADUserInfo {
    [CmdletBinding(DefaultParameterSetName = 'ByID')]
    [OutputType([ADUserInfo[]])]
    Param(
        [Parameter(ParameterSetName = 'ByID', Position = 0, ValueFromPipeline = $true)]
        [Alias('sAMAccountName', 'EmployeeID', 'LogonId')]
        [String]$UserId = $env:USERNAME,

        [Parameter(ParameterSetName = 'ByCN')]
        [ValidateLength(4, 100)]
        [Alias('CN', 'FullName')]
        [String]$Name,

        [Parameter(ParameterSetName = 'BySN')]
        [ValidateLength(2, 100)]
        [Alias('GivenName')]
        [String]$FirstName,

        [Parameter(ParameterSetName = 'BySN')]
        [ValidateLength(2, 100)]
        [Alias('SN', 'Surname')]
        [String]$LastName,

        [ValidateRange(1, 1000)]
        [Int]$Limit = 20,

        [String[]]$Properties
    )
    
    PROCESS {
        switch ($PSCmdlet.ParameterSetName) {
            'ByID' { $SubFilter = "(|(samAccountName=$UserId)(employeeID=$UserId))"; Break }
            'ByCN' { $SubFilter = "(cn=$Name)"; Break }
            'BySN' {
                if ($FirstName -and $LastName) {
                    $SubFilter = "(&(givenName=$FirstName)(sn=$LastName))"
                } else {
                    $SubFilter = if ($FirstName) { "(givenName=$FirstName)" } else { "(sn=$LastName)" }
                }
            }
        }

        $UserSearcher = [adsiSearcher]"(&(objectClass=User)$SubFilter)"
        $UserSearcher.SearchRoot = Get-ADInfoConfig -Item UserSearchRoot
        $UserSearcher.Asynchronous = $true
        $UserSearcher.SizeLimit = $Limit
        $UserSearcher.PropertiesToLoad.AddRange([ADUserInfo]::GetADProperties().Keys)
        if ($Properties) { $UserSearcher.PropertiesToLoad.AddRange($Properties) }

        Write-Verbose "Search root      : $($UserSearcher.SearchRoot.Path)"
        Write-Verbose "Search filter    : $($UserSearcher.Filter)"
        Write-Verbose "Search properties: $($UserSearcher.PropertiesToLoad -join ', ')"

        try {
            $UserSearcher.FindAll() | ForEach { [ADUserInfo]::new($_.Properties) }
        } finally {
            $UserSearcher.Dispose()
        }
    }
}
Set-Alias -Name aduser -Value Get-ADUserInfo
Set-Alias -Name adu -Value Get-ADUserInfo

<#
.SYNOPSIS
Gets one or more Active Directory groups.

.DESCRIPTION
The Get-ADGroupInfo searches Active Directory for group information based on the specified paramters.
By default this function will return the assigned groups. Specify -Recurse to get all top groups.

.PARAMETER UserId
Specifies the user id that is evaluated against either samAccountName or employeeID. 
It defaults to the current logon user if not specified. It aliases to:
- sAMAccountName
- EmployeeID
- LogonId

.PARAMETER Recurse
Specifies that the top groups, rather than the assigned groups, to be returned.

.Example
Get-ADGroupInfo

Gets all the assigned groups for current logon user

.Example
Get-ADGroupInfo -UserId abc123 -Recurse

Gets all the top groups for user abc123
#>
function Get-ADGroupInfo {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [Alias('sAMAccountName', 'EmployeeID', 'LogonId')]
        [String]$UserId = $env:USERNAME,
        
        [Switch]$Recurse
    )
    
    PROCESS {
        $User = Get-ADUserInfo -UserId $UserId -Properties memberOf
        if (@($User).Count -eq 0) {
            Write-Warning "No user found"
            Return
        } elseif (@($User).Count -gt 1) {
            $Selected = $User | Out-GridView -Title "Select the user" -PassThru
            If (@($Selected).Count -eq 0) {
                Write-Warning "No user selected"
                Return
            }
            $User = $Selected
        }

        if ($Recurse) {
            Get-TopADGroups -DNames $User.memberOf
        } else {
            Get-GivenGroups -DNames $User.memberOf
        }
    }
}
Set-Alias -Name adgroup -Value Get-ADGroupInfo
Set-Alias -Name adg -Value Get-ADGroupInfo

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


function Get-TopADGroups($DNames) {
    $Stack = [Stack[String]]::new()
    $DNames | ForEach { $Stack.Push($_) }

    $GroupSearcher = [adsiSearcher]''
    $GroupSearcher.SearchRoot = Get-ADInfoConfig -Item GroupSearchroot
    $GroupSearcher.PropertiesToLoad.AddRange([ADGroupInfo]::GetADProperties().Keys)
    $null = $GroupSearcher.PropertiesToLoad.Add('memberOf')

    while ($Stack.Count -gt 0) {
        $DName = $Stack.Pop()
        $GroupSearcher.Filter = "(&(objectClass=Group)(distinguishedName=$DName))"
        $SearchResult = $GroupSearcher.FindOne()
        $ParentGroups = $SearchResult.Properties['memberOf']
        if ($ParentGroups.Count -gt 0) {
            $ParentGroups | ForEach { $Stack.Push($_) }
        } else {
            [ADGroupInfo]::new($SearchResult.Properties)
        }
    }
    $GroupSearcher.Dispose()
}

function Get-GivenGroups($DNames) {
    $DNames | ForEach {
        [ADGroupInfo]::new(@{
            DistinguishedName = $_
            CN = $_.Substring(3, $_.IndexOf(',OU') - 3).Replace('\', '')
        })
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