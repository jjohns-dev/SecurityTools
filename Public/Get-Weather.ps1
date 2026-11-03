function Get-Weather {
    <#
    .SYNOPSIS
        Get current weather conditions for a location
    .DESCRIPTION
        Get weather conditions
    .PARAMETER City
        City
    .PARAMETER Format
        Use predefined weather format (1-4) or 'Sun'
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Get-Weather
        Get weather chart for current location
    .NOTES
        Status: Stable
        https://github.com/chubin/wttr.in
    #>
    [CmdletBinding()]
    Param(
        [Parameter(HelpMessage = 'City')]
        [ValidateNotNullOrEmpty()]
        [System.String] $City,

        [Parameter(HelpMessage = 'Predefined format')]
        #[ValidateRange(1,4)]
        [ValidateSet(1,2,3,4,'Sun')]
        [System.String] $Format
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        New-Variable -Name 'base_uri' -Value 'https://wttr.in/' -Option ReadOnly
        $uri = $base_uri

        if ($PSBoundParameters.ContainsKey('City')) {
            $fCity = $City.Replace(' ', '+')
            $uri += $fCity
        }
        if ($PSBoundParameters.ContainsKey('Format')) {
            if ($Format -IN 1..4) { $uri += '?format={0}' -f $Format }
            elseif ($Format -EQ 'Sun') { $uri += '?format="%l:+%S+%s\n"' }
        }
    }
    Process {
        Write-Verbose -Message ('Weather URL [{0}]' -f $uri)

        Invoke-RestMethod -Uri $uri
    }
}
