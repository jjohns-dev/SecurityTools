function Get-CVSSv3BaseScore {
    <#
    .SYNOPSIS
        Get CVSS v3 score for the given CVE ID
    .DESCRIPTION
        Get the first occurrence of 'CVSS 3.0 Base Score [X]' from the NVD site
        page for the given CVE ID
    .PARAMETER CVE
        CVE ID
    .INPUTS
        System.String[].
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-CVSSv3BaseScore -CVE "CVE-2020-2659"
        Scrapes the NVD NIST page and returns CVSS v3 score for CVE "CVE-2020-2659"
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, HelpMessage = 'CVE ID')]
        [ValidatePattern('CVE-\d{4}\-\d+')]
        #[ValidateScript({ $_ -match 'CVE-\d{4}\-\d+' })]
        [System.String[]] $CVE
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        $baseUri = "https://nvd.nist.gov/vuln/detail/{0}"
        $pattern = 'class="label\slabel-\w+">(\d+\.\d+)\s(\w+)</a>'
    }
    Process {
        foreach ( $c in $CVE ) {
            $uri = $baseUri -f $c

            $response = Invoke-WebRequest -Uri $uri

            $results = $response.Content | Select-String -Pattern $pattern # -AllMatches

            try {
                [PSCustomObject] @{
                    CVE      = $c
                    Score    = $results.Matches.Groups[1].Value
                    Severity = $results.Matches.Groups[2].Value
                }
            }
            catch {
                Write-Warning -Message ('No CVSS v3 score found for vulnerability [{0}]' -f $c)
            }
        }
    }
}
