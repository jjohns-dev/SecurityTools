function Convert-Hexadecimal {
    <#
    .SYNOPSIS
        Convert hexadeciaml
    .DESCRIPTION
        Convert from hexadecimal to decimal or decimal to hexadecimal
    .PARAMETER Hexadecimal
        Hexadecimal value to convert to decimal
    .PARAMETER Decimal
        Decimal value to convert to hexadecimal
    .INPUTS
        None.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Convert-Hexadecimal 4248
        Converts decimal value of 4248 to hexadecimal value
    .NOTES
        Status: Stable
    #>
    [CmdletBinding(DefaultParameterSetName = '__dcm')]
    [OutputType('System.String')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Hexadecimal value', ParameterSetName = '__hex')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Hexadecimal,

        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Decimal value', ParameterSetName = '__dcm')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Decimal
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {

        switch ($PSCmdlet.ParameterSetName) {
            '__hex' {
                # CONVERT HEXADECIMAL TO DECIMAL
                # Strip an optional 0x/0X prefix so '0x1098' and '1098' both work.
                $trimmed = $Hexadecimal -replace '^0[xX]', ''
                [System.Convert]::ToInt64($trimmed, 16).ToString()
            }
            '__dcm' {
                # CONVERT DECIMAL TO HEXADECIMAL
                #'{0:X}' -f 4248
                #[System.String]::Format('{0:X}', 4248)
                ('0x{0}' -f ([System.Convert]::ToString($Decimal, 16)))
            }
        }
    }
}
