function Expand-GZip {
    <#
    .SYNOPSIS
        Expand GZip compressed file
    .DESCRIPTION
        Expand GZip compressed file
    .PARAMETER Path
        Path to GZip file
    .PARAMETER OutputDirectory
        Destination directory to extract file to
    .PARAMETER Force
        Overwrite the destination file if it already exists.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Expand-GZip -Path C:\E3IU1BL3AWXV9B.2023-10-30-21.b3052b06.gz
        Extracts file to C:\E3IU1BL3AWXV9B.2023-10-30-21.b3052b06
    .EXAMPLE
        PS C:\> Expand-GZip -Path C:\E3IU1BL3AWXV9B.2023-10-30-21.b3052b06.gz -OutputDirectory C:\Temp
        Extracts file to C:\Temp\E3IU1BL3AWXV9B.2023-10-30-21.b3052b06
    .EXAMPLE
        PS C:\> Expand-GZip -Path C:\E3IU1BL3AWXV9B.2023-10-30-21.b3052b06.gz -Force
        Extracts file, overwriting C:\E3IU1BL3AWXV9B.2023-10-30-21.b3052b06 if it already exists
    .NOTES
        Status: Stable
        Prior art: DeGZip-File, TechNet forum reply (2013-01-02), https://learn.microsoft.com/en-us/archive/msdn-technet-forums/5aa53fef-5229-4313-a035-8b3a38ab93f5
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Path to GZip file')]
        [ValidateScript({ (Test-Path -Path $_ -PathType Leaf) -and ($_ -like '*.gz') })]
        [System.IO.FileInfo] $Path,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Destination directory to extract file to')]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [System.IO.DirectoryInfo] $OutputDirectory,

        [Parameter(Mandatory = $false, HelpMessage = 'Overwrite the destination file if it already exists')]
        [System.Management.Automation.SwitchParameter] $Force
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # CHECK FOR DESTINATION PATH
        if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
            # SET DESTINATION TO FULL, DECOMPRESSED FILE PATH
            $destFullPath = Join-Path -Path $OutputDirectory -ChildPath (Split-Path -Path $Path -LeafBase)
        }
        else {
            # IF NO DESTINATION PATH IS PROVIDED, USE THE SAME PATH AS THE GZIP FILE BUT WITHOUT THE .GZ EXTENSION
            $destFullPath = Join-Path -Path (Split-Path -Path $Path) -ChildPath (Split-Path -Path $Path -LeafBase)
        }

        # REFUSE TO OVERWRITE AN EXISTING DESTINATION UNLESS -Force WAS PASSED
        if ((Test-Path -Path $destFullPath -PathType Leaf) -and -not $Force) {
            $errParams = @{
                Message     = 'Destination file [{0}] already exists. Use -Force to overwrite.' -f $destFullPath
                Category    = 'ResourceExists'
                ErrorAction = 'Stop'
            }
            Write-Error @errParams
        }

        # OUTPUT VERBOSE MESSAGE
        Write-Verbose -Message ('Expanding GZip file [{0}] to [{1}]' -f $Path, $destFullPath)

        # HONOR -WhatIf / -Confirm
        if (-not $PSCmdlet.ShouldProcess($destFullPath, 'Expand-GZip')) {
            return
        }

        # DECOMPRESS SOURCE INTO DESTINATION, DISPOSING EVERY STREAM EVEN ON FAILURE
        $source = [System.IO.File]::OpenRead($Path.FullName)
        try {
            $gzip = [System.IO.Compression.GZipStream]::new($source, [System.IO.Compression.CompressionMode]::Decompress)
            try {
                $destination = [System.IO.File]::Create($destFullPath)
                try { $gzip.CopyTo($destination) } finally { $destination.Dispose() }
            }
            finally { $gzip.Dispose() }
        }
        finally { $source.Dispose() }
    }
}
