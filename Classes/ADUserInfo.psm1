using module .\ADAttributeAnnotation.psm1

<#
.SYNOPSIS
Defines properties and its respective AD attributes for a user object

.DESCRIPTION
This class serves a container for user information in Active Directory.

Its layout is defined in ADUserInfo.Format.ps1xml.

Beaware that any change to class is not picked up with Import-Module -Force
during developement. Workaround is to run PowerShell.exe before importing 
module with class changes. See the following links for the bug details:
- https://github.com/PowerShell/PowerShell/issues/2505#issuecomment-263105859
- https://stackoverflow.com/questions/42838107/remove-class-from-memory-in-powershell/42878789#42878789
#>
class ADUserInfo {
    [ADAttribute()]
    [String] $DistinguishedName

    [ADAttribute('GivenName')]
    [String] $FirstName

    [ADAttribute('SN')]
    [String] $LastName

    [ADAttribute('CN')]
    [String] $FullName

    [ADAttribute('sAMAccountName')]
    [String] $EmployeeID

    [ADAttribute('Title')]
    [String] $JobTitle

    [ADAttribute()]
    [String] $Description

    [ADAttribute('TelephoneNumber')]
    [String] $Telephone

    [ADAttribute()]
    [String] $Mobile

    [ADAttribute()]
    [String] $Mail

    [ADAttribute()]
    [String] $Manager

    [ADAttribute()]
    [string] $Division

    [ADAttribute()]
    [String] $Department

    [ADAttribute('WhenCreated')]
    [String] $CreatedDateTime

    [ADAttribute('AccountExpires')]
    hidden [String] $_AccountExpires

    static [Hashtable] $AD_PROPERTIES = $null # AD attributes => ADUserInfo properties

    static [Hashtable] GetADProperties() {
        if ($null -eq [ADUserInfo]::AD_PROPERTIES) {
            [ADUserInfo]::AD_PROPERTIES = @{}
            [ADUserInfo].GetProperties() | Where {$_.CustomAttributes.AttributeType -contains [ADAttribute]} | ForEach {
                $ADAttributeName = $_.GetCustomAttributes([ADAttribute], $false)[0].AttributeName
                if ([String]::IsNullOrEmpty($ADAttributeName)) { $ADAttributeName = $_.Name }

                [ADUserInfo]::AD_PROPERTIES[$ADAttributeName] = $_.Name
            }
        }
        return [ADUserInfo]::AD_PROPERTIES
    }

    ADUserInfo($Attributes) {
        $ADProperties = [ADUserInfo]::GetADProperties()
        $Attributes.Keys | ForEach {
            $PropertyValue = $Attributes[$_]

            if ($PropertyValue.Count -eq 1) {
                $PropertyValue = $PropertyValue | Select -First 1
            }

            if ($ADProperties.Keys -contains $_) {
                $PropertyName = $ADProperties[$_]
                $this.$PropertyName = $PropertyValue
            } elseif ('adspath' -ne $_) {
                $this | Add-Member -MemberType NoteProperty -Name $_ -Value $PropertyValue
            }
        }
        
        $this | Add-Member -MemberType ScriptProperty -Name "ManagerName" -Value {
            $this.Manager.Substring(3, $this.Manager.IndexOf(',OU') - 3).Replace('\', '')
        }

        $this | Add-Member -MemberType ScriptProperty -Name "AccountExpires" -Value {
            if (($this._AccountExpires -eq 0) -or ($this._AccountExpires -gt  [DateTime]::MaxValue.Ticks)) {
                "<Never>"
            } else {
                [Datetime]::FromFileTime($this._AccountExpires)
            }
        }
    }
}