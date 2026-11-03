function Get-CountryCode {
    <#
    .SYNOPSIS
        Get Country Code
    .DESCRIPTION
        Get country from 2- or 3-letter country code
    .PARAMETER Code
        Country code (2- or 3-letter)
    .PARAMETER Country
        Country name
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-CountryCode AS
        Returns the country data for "American Samoa"
    .NOTES
        Status: Stable
        Data: Private/ISO-3166.csv, from datahub.io "country-list" (ODC-PDDL-1.0), derived from ISO 3166-1
        https://www.iso.org/obp/ui/#search
        https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
        https://datahub.io/core/country-list
    #>
    [CmdletBinding(DefaultParameterSetName = '__cde')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'Country',
        Justification = 'Used inside a .Where() scriptblock, which the analyzer does not trace into.'
    )]
    Param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = '__cde', HelpMessage = 'Country code (2- or 3-letter)')]
        [ValidatePattern('^[A-Z]{2,3}$')]
        [System.String] $Code,

        [Parameter(Mandatory, Position = 0, ParameterSetName = '__cty', HelpMessage = 'Country name')]
        [ValidatePattern('^[\w\s-]+$')]
        [System.String] $Country
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # LOOKUP VALUE IN THE ISO 3166 TABLE LOADED BY THE MODULE AT IMPORT
        switch ($PSCmdlet.ParameterSetName) {
            '__cde' {
                # CHECK CODE LENGTH
                if ($Code.Length -EQ 2) { $CountryCodes.Where({ $_.'Alpha-2 code' -EQ $Code }) }
                else { $CountryCodes.Where({ $_.'Alpha-3 code' -EQ $Code }) }
            }
            '__cty' {
                # MATCH COUNTRY
                $CountryCodes.Where({ $_.'English short name' -Like ('*{0}*' -f $Country) })
            }
        }
    }
}
