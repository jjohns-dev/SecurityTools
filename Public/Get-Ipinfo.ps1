function Get-Ipinfo {
    <#
    .SYNOPSIS
        Get IP address info
    .DESCRIPTION
        Get IP address info
    .PARAMETER IPAddress
        IPV4 address
    .INPUTS
        System.Net.IPAddress[].
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-Ipinfo -IPAddress '1.1.1.1'
        Get IP address info for IP '1.1.1.1'
    .NOTES
        Status: Stable
        https://ipinfo.io/
        To get more data (e.g., ASN or Company info) a token must be used
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = 'IPV4 address')]
        [System.Net.IPAddress[]] $IPAddress
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        $baseUrl = "https://ipinfo.io/"
        $headers = @{ accept = "application/json" }
    }
    Process {
        foreach ( $ip in $IPAddress ) {
            $url = '{0}{1}' -f $baseUrl, $ip

            Write-Verbose -Message ('Getting Ipinfo for [{0}]' -f $ip)

            try {
                Invoke-RestMethod -Uri $url -Headers $headers -Method "GET"
            }
            catch {
                Write-Error -Message ('Error retrieving IP info for IP: {0}' -f $ip)
            }
        }
    }
}
