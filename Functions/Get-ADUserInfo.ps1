<#
.SYNOPSIS
Gets one or more Active Directory users.

.DESCRIPTION
The Get-ADUserInfo searches Active Directory for user information based on the specified paramters.

All the search parameters (UserId, Name, FirstName, LastName, Mail) accepts the wildcards. 
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
Specifies the common name (CN) of an Active Directory user entry. It requires minimum of 4 characters. 
It aliases to:
- CN
- FullName

.PARAMETER FirstName
Specifies the given name (GivenName) of an Active Directory user entry. It requires minimum of 2 characters. 
It aliases to:
- GivenName

.PARAMETER LastName
Specifies the surname (SN) of an Active Directory user entry. It requires minimum of 2 characters. 
It aliases to:
- SN
- Surname

.PARAMETER Mail
Specifies the mail of an Active Directory user entry. It requires minimum of 2 characters.

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

Gets the first 10 users with the first name as 'Alex'

.Example
Get-ADUserInfo SamAlex -Properties personalTitle, memberOf, pwdLastSet | fl *

Gets the information for the user whose SamAccountName/LogonId/EmployeeId is 'SamAlex'
and fetches additional information: personalTitle, memberOf, and pwdLastSet
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