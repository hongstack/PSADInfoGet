<#
.SYNOPSIS
Gets one or more Active Directory users.

.DESCRIPTION
The Get-ADUserInfo searches Active Directory for user information based on the specified paramters.

All parameters accept the wildcards:
- *    : Matches zero or more characters
- ?    : Matches any character
- [ac] : Matches 'a' or 'c'
- [a-c]: Matches 'a', 'b', 'c'

.PARAMETER UserId
Specifies the user id which is evaluated against either samAccountName or employeeID. 
It defaults to the current logon user if not specified. It aliases to:
- sAMAccountName
- EmployeeID
- LogonId

.PARAMETER Name
Specifies the common name (CN) of Active Directory users. Minimum of 4 characters required.
It aliases to:
- CN
- FullName

.PARAMETER FirstName
Specifies the given name (GivenName) of Active Directory users. Minimum of 2 characters required.
It aliases to:
- GivenName

.PARAMETER LastName
Specifies the surname (SN) of Active Directory users. Minimum of 2 characters required.
It aliases to:
- SN
- Surname

.PARAMETER Mail
Specifies the mail of Active Directory users. Minimum of 2 characters required.

.PARAMETER GroupName
Specifies the common name (CN) of Active Directory groups. Minimum of 2 characters required.
This parameter gets all users that are assigned to the requested group and its nested groups.

.PARAMETER Limit
Specifies the maximum number of results to return, default to 20.
This parameter has no effect when searching by GroupName.

.PARAMETER Properties
Specifies additional Active Directory properties (comma-separated) to be returned.
This parameter has no effect when searching by GroupName. 

Use 'Format-List *' to display all of the properties.

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

Gets the information for users whose common name contains 'Smith'.

.Example
Get-ADUserInfo -FirstName Alex -Limit 10

Gets the first 10 users whose first name is 'Alex'

.Example
Get-ADUserInfo SamAlex -Properties personalTitle, memberOf, pwdLastSet | fl *

Gets the information for usesr whose SamAccountName or EmployeeId is 'SamAlex'
and fetches additional information: personalTitle, memberOf, and pwdLastSet.

.Example
Get-ADUserInfo -GroupName Test_Group | Where manager -ne $null

Gets all users assigned to Activity Directory group 'Test_Group' and its nested groups.
Filter out any users who don't have manager
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

        [Parameter(ParameterSetName = 'ByML')]
        [ValidateLength(2, 100)]
        [String]$Mail,

        [Parameter(ParameterSetName = 'ByGN')]
        [ValidateLength(2, 100)]
        [String]$GroupName,

        [ValidateRange(1, 1000)]
        [Int]$Limit = 20,

        [String[]]$Properties
    )
    
    PROCESS {
        if ($PSCmdlet.ParameterSetName -eq 'ByGN') {
            Get-ADUsersByGroup -GroupName $GroupName
            return
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ByID' { $SubFilter = "(|(samAccountName=$UserId)(employeeID=$UserId))"; Break }
            'ByCN' { $SubFilter = "(cn=$Name)"; Break }
            'BySN' {
                if ($FirstName -and $LastName) {
                    $SubFilter = "(&(givenName=$FirstName)(sn=$LastName))"
                } else {
                    $SubFilter = if ($FirstName) { "(givenName=$FirstName)" } else { "(sn=$LastName)" }
                }
                break
            }
            'ByML' { $SubFilter = "(mail=$Mail)"; Break }
        }

        $UserSearcher = [adsiSearcher]"(&(objectClass=User)$SubFilter)"
        $UserSearcher.SearchRoot = Get-ADInfoConfig -Item UserSearchRoot
        $UserSearcher.Asynchronous = $true
        $UserSearcher.SizeLimit = $Limit
        $UserSearcher.PropertiesToLoad.AddRange([ADUserInfo]::GetADProperties().Keys)
        if ($Properties) { $UserSearcher.PropertiesToLoad.AddRange($Properties) }

        Write-Verbose "Search root      : $($UserSearcher.SearchRoot.Path)"
        Write-Verbose "Search filter    : $($UserSearcher.Filter)"
        Write-Verbose "Return properties: $($UserSearcher.PropertiesToLoad -join ', ')"

        try {
            $UserSearcher.FindAll() | ForEach { [ADUserInfo]::new($_.Properties) }
        } finally {
            $UserSearcher.Dispose()
        }
    }
}
Set-Alias -Name aduser -Value Get-ADUserInfo
Set-Alias -Name adu -Value Get-ADUserInfo


function Get-ADUsersByGroup($GroupName) {
    $Groups = Get-ADGroupInfo -GroupName $GroupName -Properties member

    if ($Groups.Count -eq 0) {
        Write-Warning "No group found"
        Return
    } elseif ($Groups.Count -gt 1) {
        $Group = $Groups | Out-GridView -Title "Select the group" -PassThru
        If ($null -eq $Group) {
            Write-Warning "No group selected"
            Return
        }
    } else {
        $Group = $Groups[0]
    }

    if ($null -eq $Group.member) {
        return
    }

    $Stack = [Stack[String]]::new()
    $Group.member | ForEach { $Stack.Push($_) }

    $Searcher = [adsiSearcher]''
    $Searcher.PropertiesToLoad.AddRange([ADUserInfo]::GetADProperties().Keys)
    $null = $Searcher.PropertiesToLoad.AddRange(@('member','objectClass'))

    $Processed = [HashSet[String]]::new()
    while ($Stack.Count -gt 0) {
        $DName = $Stack.Pop()
        if ($Processed.Contains($DName)) {
            continue
        } else {
            [Void]$Processed.Add($DName)
        }
        $Searcher.Filter = "(distinguishedName=$DName)"
        $SearchResult = $Searcher.FindOne()
        $ObjectClass = $SearchResult.Properties['objectClass']
        if ($ObjectClass.Contains('user') -or $ObjectClass.Contains('person')) {
            [ADUserInfo]::new($SearchResult.Properties)
        } elseif ($ObjectClass.Contains('group')) {
            Write-Verbose "Found nested group: $DName"
            if ($SearchResult.Properties['member'].Count -gt 0) {
                $SearchResult.Properties['member'] | ForEach { $Stack.Push($_) }
            }
        } else {
            Write-Warning "Unknown object class for $DName"
        }
    }
    $Searcher.Dispose()
}