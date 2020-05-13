<#
.SYNOPSIS
Gets one or more Active Directory groups.

.DESCRIPTION
The Get-ADGroupInfo searches Active Directory for group information based on the specified paramters.
By default this function will return the assigned groups. Specify -Recurse to get all top groups.

All the search parameters (UserId, GroupName, GroupMail) accepts the wildcards. 
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

.PARAMETER GroupName
Specifies the common name (CN) of an Active Directory group entry. It requires minimum of 2 characters. 
It aliases to:
- CN

.PARAMETER GroupMail
Specifies the mail of an Active Directory group entry. It requires minimum of 2 characters. 
It aliases to:
- mail

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
    [CmdletBinding(DefaultParameterSetName = 'ByUID')]
    [OutputType([ADGroupInfo[]])]
    Param(
        [Parameter(ParameterSetName = 'ByUID', Position = 0, ValueFromPipeline = $true)]
        [Alias('sAMAccountName', 'EmployeeID', 'LogonId')]
        [String]$UserId = $env:USERNAME,

        [Parameter(ParameterSetName = 'ByGNM')]
        [ValidateLength(2, 100)]
        [Alias('cn')]
        [String]$GroupName,

        [Parameter(ParameterSetName = 'ByGML')]
        [ValidateLength(2, 100)]
        [Alias('mail')]
        [String]$GroupMail,
        
        [Switch]$Recurse
    )
    
    PROCESS {
        if ($PSCmdlet.ParameterSetName -eq 'ByUID') {
            $User = Get-ADUserInfo -UserId $UserId -Properties memberOf
            Get-ADGroupsByUser -User $User -Recurse:$Recurse
            return
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ByGNM' { $SubFilter = "(cn=$GroupName)"; Break }
            'ByGML' { $SubFilter = "(mail=$GroupMail)"; Break }
        }

        $GroupSearcher = [adsiSearcher]"(&(objectClass=Group)$SubFilter)"
        $GroupSearcher.SearchRoot = Get-ADInfoConfig -Item GroupSearchroot
        $GroupSearcher.Asynchronous = $true
        $GroupSearcher.SizeLimit = 20
        $GroupSearcher.PropertiesToLoad.AddRange([ADGroupInfo]::GetADProperties().Keys)

        Write-Verbose "Search root  : $($GroupSearcher.SearchRoot.Path)"
        Write-Verbose "Search filter: $($GroupSearcher.Filter)"

        try {
            $GroupSearcher.FindAll() | ForEach { [ADGroupInfo]::new($_.Properties) }
        } finally {
            $GroupSearcher.Dispose()
        }
    }
}
Set-Alias -Name adgroup -Value Get-ADGroupInfo
Set-Alias -Name adg -Value Get-ADGroupInfo

function Get-ADGroupsByUser($User, $Recurse) {
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