<#
.SYNOPSIS
Annotate a property to be an AD attribute

.DESCRIPTION
The ADAttribute annotates class properties to make them become the properties to search in 
Active Directory. 

If the AttributeName is specified, this will be the attribute to search in the AD and 
default to the property name otherwise.

Note that this attribute definition must not put in the same file as the attirbute user
because of PowerShell bug.

See the following links for the bug details:
- https://github.com/PowerShell/PowerShell/issues/2642
- https://github.com/PowerShell/PowerShell/issues/1762
#>
Class ADAttribute : Attribute {
    [String] $AttributeName

    ADAttribute() {}

    ADAttribute([String] $AttributeName) {
        $this.AttributeName = $AttributeName
    }
}