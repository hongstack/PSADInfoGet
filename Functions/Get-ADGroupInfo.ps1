<#
.SYNOPSIS
Gets one or more Active Directory groups.

.DESCRIPTION
The Get-ADGroupInfo searches Active Directory for group information based on the specified paramters.

All parameters accept the wildcards:
- *    : Matches zero or more characters
- ?    : Matches any character
- [ac] : Matches 'a' or 'c'
- [a-c]: Matches 'a', 'b', 'c'

.PARAMETER UserId
Specifies the user id which is evaluated against either samAccountName or employeeID. 
This parameter gets all groups this user assigned to.
It defaults to the current logon user if not specified. It aliases to:
- sAMAccountName
- EmployeeID
- LogonId

.PARAMETER Recurse
Specifies that the top groups, rather than the assigned groups, to be returned.

.PARAMETER GroupName
Specifies the common name (CN) of Active Directory groups. Minimum of 2 characters required.
It aliases to:
- CN

.PARAMETER GroupMail
Specifies the mail of Active Directory groups. Minimum of 2 characters required.
It aliases to:
- mail

.PARAMETER Limit
Specifies the maximum number of results to return, default to 20.
This parameter has no effect when searching by UserId.

.PARAMETER Properties
Specifies additional Active Directory properties (comma-separated) to be returned.
This parameter has no effect when searching by UserId. 

Use 'Format-List *' to display all of the properties.

.Example
Get-ADGroupInfo

Gets all the assigned groups for current logon user

.Example
Get-ADGroupInfo -UserId abc123 -Recurse

Gets all the top groups for user abc123

.Example
Get-ADGroupInfo -GroupName *Test*

Gets all groups which common name contains 'Test'

.Example
Get-ADGroupInfo -GroupMail test@example.com

Gets the group which mail is 'test@example.com'
#>
function Get-ADGroupInfo {
    [CmdletBinding(DefaultParameterSetName = 'ByUID')]
    [OutputType([ADGroupInfo[]])]
    Param(
        [Parameter(ParameterSetName = 'ByUID', Position = 0, ValueFromPipeline = $true)]
        [Alias('sAMAccountName', 'EmployeeID', 'LogonId')]
        [String]$UserId = $env:USERNAME,

        [Parameter(ParameterSetName = 'ByUID')]
        [Switch]$Recurse,

        [Parameter(ParameterSetName = 'ByGNM')]
        [ValidateLength(2, 100)]
        [Alias('cn')]
        [String]$GroupName,

        [Parameter(ParameterSetName = 'ByGML')]
        [ValidateLength(2, 100)]
        [Alias('mail')]
        [String]$GroupMail,
		
		[ValidateRange(1, 1000)]
        [Int]$Limit = 20,

        [String[]]$Properties
    )
    
    PROCESS {
        if ($PSCmdlet.ParameterSetName -eq 'ByUID') {
            Get-ADGroupsByUser -UserId $UserId -Recurse:$Recurse
            return
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ByGNM' { $SubFilter = "(cn=$GroupName)"; Break }
            'ByGML' { $SubFilter = "(mail=$GroupMail)"; Break }
        }

        $GroupSearcher = [adsiSearcher]"(&(objectClass=Group)$SubFilter)"
        $GroupSearcher.SearchRoot = Get-ADInfoConfig -Item GroupSearchroot
        $GroupSearcher.Asynchronous = $true
        $GroupSearcher.SizeLimit = $Limit
        $GroupSearcher.PropertiesToLoad.AddRange([ADGroupInfo]::GetADProperties().Keys)
        if ($Properties) { $GroupSearcher.PropertiesToLoad.AddRange($Properties) }

        Write-Verbose "Search root      : $($GroupSearcher.SearchRoot.Path)"
        Write-Verbose "Search filter    : $($GroupSearcher.Filter)"
		Write-Verbose "Return properties: $($GroupSearcher.PropertiesToLoad -join ', ')"

        try {
            $GroupSearcher.FindAll() | ForEach { [ADGroupInfo]::new($_.Properties) }
        } finally {
            $GroupSearcher.Dispose()
        }
    }
}
Set-Alias -Name adgroup -Value Get-ADGroupInfo
Set-Alias -Name adg -Value Get-ADGroupInfo

function Get-ADGroupsByUser($UserId, $Recurse) {
    $Users = Get-ADUserInfo -UserId $UserId -Properties memberOf

    if ($Users.Count -eq 0) {
        Write-Warning "No user found"
        Return
    } elseif ($Users.Count -gt 1) {
        $User = $Users | Out-GridView -Title "Select the user" -PassThru
        If ($null -eq $User) {
            Write-Warning "No user selected"
            Return
        }
    } else {
        $User = $Users[0]
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