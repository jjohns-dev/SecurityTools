function ConvertTo-Hex {
    <#
    .SYNOPSIS
        Convert Char to Hex
    .DESCRIPTION
        Convert character (System.Char) to hexidecimal
    .PARAMETER Character
        Character (Char)
    .INPUTS
        System.Char.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> ConvertTo-Hex -Character 'A'
        Returns the hexadecimal value 0x41 for the character 'A'.
    .NOTES
        Status: Stable
        TO CONVERT FROM HEX TO CHAR USE THE CODE BELOW
        [System.Char] 0x21
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, HelpMessage = 'Character')]
        #[ValidateScript({ Test-Path -Path $_ -PathType Leaf -Filter "*.json" })]
        [System.Char[]] $Character
    )
    Begin {
        # OUTPUT VERBOSE MESSAGE
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # LOOP ALL INPUT
        foreach ($char in $Character) {

            # CONVERT CHARACTER (CHAR) TO HEX
            [PSCustomObject] @{
                Char = $char
                Hex  = '0x{0:X2}' -f [System.Int32]([System.Byte][System.Char]$char)
            }
        }
    }
}
