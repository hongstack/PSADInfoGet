using module .\ADAttributeAnnotation.psm1

Class ADGroupInfo {
    [ADAttribute()]
    [String] $DistinguishedName

    [ADAttribute('CN')]
    [String] $Name

    [ADAttribute()]
    [String] $Info

    [ADAttribute('WhenCreated')]
    hidden [String] $CreatedDateTime

    #[String[]] $Members

    static [Hashtable] $AD_PROPERTIES = $null # AD attributes => ADUserInfo properties

    static [Hashtable] GetADProperties() {
        if ($null -eq [ADGroupInfo]::AD_PROPERTIES) {
            [ADGroupInfo]::AD_PROPERTIES = @{}
            [ADGroupInfo].GetProperties() | Where {$_.CustomAttributes.AttributeType -contains [ADAttribute]} | ForEach {
                $ADAttributeName = $_.GetCustomAttributes([ADAttribute], $false)[0].AttributeName
                if ([String]::IsNullOrEmpty($ADAttributeName)) { $ADAttributeName = $_.Name }

                [ADGroupInfo]::AD_PROPERTIES[$ADAttributeName] = $_.Name
            }
        }
        return [ADGroupInfo]::AD_PROPERTIES
    }

    ADGroupInfo($Attributes) {
        $ADProperties = [ADGroupInfo]::GetADProperties()
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
        
        $this | Add-Member -MemberType ScriptProperty -Name "ShortInfo" -Value {
            if (-not [String]::IsNullOrEmpty($this.info)) {
                $Line = $this.info -replace "\s*[`n]+", "; "
                if ($Line.Length -gt 75) {
                    '{0}...' -f $Line.Substring(0, 72)
                } else {
                    $Line
                }
            }
        }
    }
}