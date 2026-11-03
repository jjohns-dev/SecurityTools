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
        Prior art: "GZip in PowerShell", dorkbrain.com (2017; original page no longer available)
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
            # DECODE FIRST SO A BAD BASE64 STRING THROWS BEFORE ANY STREAM IS OPENED
            $compressed = [System.IO.MemoryStream]::new([System.Convert]::FromBase64String($str))
            try {
                $gzip = [System.IO.Compression.GZipStream]::new($compressed, [System.IO.Compression.CompressionMode]::Decompress)
                try {
                    $reader = [System.IO.StreamReader]::new($gzip, [System.Text.Encoding]::UTF8)
                    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
                }
                finally { $gzip.Dispose() }
            }
            finally { $compressed.Dispose() }
        }
    }
}
