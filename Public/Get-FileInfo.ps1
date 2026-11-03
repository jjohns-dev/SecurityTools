function Get-FileInfo {
    <#
    .SYNOPSIS
        Get file information
    .DESCRIPTION
        Get file information based on file header bytes from Wikipedia
    .PARAMETER Signature
        File signature
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-FileInfo -Signature '50 4B 03 04'
        Get information on a file with signature '50 4B 03 04'
    .NOTES
        Status: Stable
        Data: Private/FileSignatures.json, derived from Wikipedia, "List of file signatures" (CC BY-SA 4.0)
        https://en.wikipedia.org/wiki/List_of_file_signatures
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, HelpMessage = 'File signature')]
        [ValidatePattern('^[A-Za-z0-9\s]+$')]
        [System.String] $Signature
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # LOOKUP VALUE IN THE SIGNATURE TABLE LOADED BY THE MODULE AT IMPORT
        $FileSignatures | Where-Object Hex_signature -Match $Signature
    }
}
