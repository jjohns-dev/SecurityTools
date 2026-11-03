function Read-EncryptedFile {
    <#
    .SYNOPSIS
        Read encrypted file
    .DESCRIPTION
        Read encrypted file
    .PARAMETER Path
        Path to encrypted file
    .PARAMETER Key
        Encryption key
    .PARAMETER KeyBytes
        Encryption key in byte array
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Read-EncryptedFile -Path C:\temp\mySettings -Key 'Password123'
        Decrypts user settings from file mySettings with the encryption key specified
    .NOTES
        Status: Stable
        Originally written by Tim Curwick in PowerShell Conference Book 2
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [System.String] $Path,

        [Parameter(Mandatory, ParameterSetName = '__key')]
        [System.String] $Key,

        [Parameter(Mandatory, ParameterSetName = '__keybytes')]
        [System.Byte[]] $KeyBytes
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        try {
            # If the key was provided as a string Convert it to bytes
            if ( $Key ) { $KeyBytes = [System.Byte[]]$Key.ToCharArray() }

            # If the key is not 256 bits Pad it or truncate it as needed
            if ( $KeyBytes.Count -ne 32 ) { $KeyBytes = ( $KeyBytes + [System.Byte[]]'ThePaddingToUseIfWeNeedMoreBytes'.ToCharArray() )[0..31] }

            # Create cryptography engine
            $crypto = New-Object -TypeName System.Security.Cryptography.RijndaelManaged

            # Set key
            $crypto.Key = $KeyBytes

            # Use hash of key for initializing vector
            $crypto.IV = (New-Object -TypeName Security.Cryptography.SHA256Managed).ComputeHash( $crypto.Key )[0..15]

            # Create decryptor
            $decryptor = $crypto.CreateDecryptor()

            # Open file stream from source file
            $fileStream = New-Object System.IO.FileStream -ArgumentList @( $Path, [System.IO.FileMode]::Open )

            # Plumb the file stream into a cryptography stream with decryptor
            $cryptoStream = New-Object -TypeName Security.Cryptography.CryptoStream -ArgumentList @( $fileStream, $decryptor, "Read" )

            # Create stream reader to get the data
            $streamReader = New-Object -TypeName IO.StreamReader $cryptoStream

            ## Turn on the spigot and get the results,
            ## dumping them directly into the output stream
            $streamReader.ReadToEnd()
        }
        catch {
            # THROW ORIGINAL ERROR
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        finally {
            # CLEAN UP
            if ( $streamReader ) { $streamReader.Close() }
            if ( $cryptoStream ) { $cryptoStream.Close() }
            if ( $fileStream ) { $fileStream.Close() }
            if ( $crypto ) { $crypto.Clear() }
        }
    }
}
