function Get-WhoIs {
    <#
    .SYNOPSIS
        Get WhoIs information
    .DESCRIPTION
        Get WhoIs information
    .PARAMETER IPAddress
        Target IP address
    .INPUTS
        System.Net.IPAddress[].
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-WhoIs -IPAddress '8.8.8.8'
        Get's WhoIs info for the ip 8.8.8.8
    .NOTES
        Status: Stable
        https://www.powershellgallery.com/packages/PSScriptTools/2.9.0/Content/functions%5CGet-WhoIs.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param (
        [Parameter(Position = 0,
            Mandatory,
            HelpMessage = 'Enter an IPV4 address to lookup with WhoIs',
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [System.Net.IPAddress[]] $IPAddress
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
        $baseURL = 'https://whois.arin.net/rest'
        # ARIN defaults to XML, but set Accept explicitly so a server-side default change can't break us
        $header = @{ 'Accept' = 'application/xml' }
    }
    Process {
        foreach ( $ip in $IPAddress ) {
            Write-Verbose -Message ('Getting WhoIs information for {0}' -f $ip)
            $url = '{0}/ip/{1}' -f $baseURL, $ip
            try {
                $r = Invoke-RestMethod -Uri $url -Headers $header -ErrorAction Stop
                Write-Verbose -Message ($r.net | Out-String)
            }
            catch {
                $errMsg = 'Failed to retrieve WhoIs information for [{0}] with error: {1}' -f $ip, $_.Exception.Message
                Write-Error -Message $errMsg
            }

            if ($r.net) {
                Write-Verbose -Message 'Creating result'
                [PSCustomObject] @{
                    PSTypeName             = 'WhoIsResult'
                    IP                     = $ip
                    Name                   = $r.net.name
                    RegisteredOrganization = $r.net.orgRef.name
                    City                   = (Invoke-RestMethod $r.net.orgRef.'#text').org.city
                    StartAddress           = $r.net.startAddress
                    EndAddress             = $r.net.endAddress
                    NetBlocks              = $r.net.netBlocks.netBlock | ForEach-Object { '{0}/{1}' -f $_.startaddress, $_.cidrLength }
                    Updated                = $r.net.updateDate -as [System.DateTime]
                }
            }
        }
    }
    End {
        Write-Verbose -Message ('Ending {0}' -f $MyInvocation.MyCommand)
    }
}
