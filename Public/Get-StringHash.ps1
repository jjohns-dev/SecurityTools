function Get-StringHash {
    <#
    .SYNOPSIS
        Generate hash
    .DESCRIPTION
        Generate hash from string input
    .PARAMETER String
        String to has
    .PARAMETER Algorithm
        Algorithm used to generate hash
    .INPUTS
        System.String.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Get-StringHash -String 'String' -Algorithm SHA256
        Generate the SHA256 hash value of "String"
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'String to hash')]
        [System.String] $String,

        [Parameter(HelpMessage = 'Hashing algorithm to use')]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [System.String] $Algorithm = 'SHA256'
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # THE TYPE COULD BE CHANGED FROM ASCII TO UTF8 OR UNICODE
        # DEPENDING ON THE STRING INPUT
        #$inputBytes = [System.Text.Encoding]::ASCII.GetBytes($String)
        $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($String)
        Write-Verbose -Message ('Using {0} encoding' -f 'UTF8')

        $ag = switch ($Algorithm) {
            'MD5' { [System.Security.Cryptography.MD5]::Create() }
            'SHA1' { [System.Security.Cryptography.SHA1]::Create() }
            'SHA256' { [System.Security.Cryptography.SHA256]::Create() }
            'SHA512' { [System.Security.Cryptography.SHA512]::Create() }
        }
        Write-Verbose -Message ('Using algorithm {0}' -f $Algorithm)

        $stringBuilder = New-Object System.Text.StringBuilder

        Write-Verbose -Message 'Computing hash...'
        try {
            $ag.ComputeHash($inputBytes) | ForEach-Object -Process {
                # APPENDING TO THE STRING BUILDER PRINTS TO THE CONSOLE
                # THE VOID REMOVES THAT CONSOLE OUTPUT
                [void] $stringBuilder.Append($_.ToString("x2"))
            }
        }
        finally {
            $ag.Dispose()
        }

        $StringBuilder.ToString()
    }
}
