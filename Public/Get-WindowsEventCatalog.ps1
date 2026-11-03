function Get-WindowsEventCatalog {
    <#
    .SYNOPSIS
        Get catalog of Windows Events
    .DESCRIPTION
        Get catalog of Windows Events
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-WindowsEventCatalog
        Returns catalog of Windows Events
    .NOTES
        Status: Stable
        Data: Private/windows_signatures_850.csv, compiled by Justin Johns from public Windows event documentation
        and SIEM references
    #>
    [CmdletBinding()]
    Param()
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # SET LOCAL PATH
        $path = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Private' | Join-Path -ChildPath 'windows_signatures_850.csv'
    }
    Process {
        # GET DATA
        Import-Csv -Path $path
    }
}
