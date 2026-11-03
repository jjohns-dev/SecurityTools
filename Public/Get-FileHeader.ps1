function Get-FileHeader {
    <#
    .SYNOPSIS
        Get file header
    .DESCRIPTION
        Get the desired number of bytes (starting from the beginning) of a file
        (a.k.a., magic numbers)
    .PARAMETER Path
        File path
    .PARAMETER Bytes
        Number of bytes
    .INPUTS
        System.String.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Get-FileHeader -Path "C:\myFile.xlsx"
        Returns the first 4 bytes as hex
    .NOTES
        Status: Stable
        https://stackoverflow.com/questions/26194071/recognize-file-types-in-powershell
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, HelpMessage = 'File path')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [System.String] $Path,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Number of bytes')]
        [ValidateRange(2, 100)]
        [System.Int16] $Bytes = 4
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # GET BYTES OF FILE
        $fileBytes = [System.IO.File]::ReadAllBytes($Path)

        # CONVERT FIRST 4 BYTES TO HEX
        $header = 0..($Bytes-1) | ForEach-Object -Process { '{0:X2}' -f $fileBytes[$_] }

        # RETURN HEADER AS STRING
        $header -join ' '
    }
}
