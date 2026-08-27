function ConvertFrom-GZipString {
    <#
    .SYNOPSIS
        Decompresses a Base64 GZipped string
    .DESCRIPTION
        Decompresses a Base64 GZipped string
    .PARAMETER String
        Base64 encoded GZipped string
    .INPUTS
        System.String.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> $compressedString | ConvertFrom-GZipString
        Decompresses and returns the original string from a Base64 GZipped string.
    .LINK
        ConvertTo-GZipString
    .NOTES
        Status: Stable
        https://www.dorkbrain.com/docs/2017/09/02/gzip-in-powershell/
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.String[]] $String
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        foreach ($str in $String) {
            $memStream = $null; $gzipStream = $null; $reader = $null
            try {
                $compressedBytes = [System.Convert]::FromBase64String($str)
                $memStream = New-Object System.IO.MemoryStream
                $memStream.Write($compressedBytes, 0, $compressedBytes.Length)
                $memStream.Seek(0, 0) | Out-Null
                $gzipStream = New-Object System.IO.Compression.GZipStream($memStream, [System.IO.Compression.CompressionMode]::Decompress)
                $reader = New-Object System.IO.StreamReader($gzipStream)
                $reader.ReadToEnd()
            }
            finally {
                if ($reader) { $reader.Dispose() }
                if ($gzipStream) { $gzipStream.Dispose() }
                if ($memStream) { $memStream.Dispose() }
            }
        }
    }
}
