function Get-DomainRegistration {
    <#
    .SYNOPSIS
        Get domain registration info
    .DESCRIPTION
        Get domain registration info
    .PARAMETER ApiKey
        API Key
    .PARAMETER Domain
        Target Domain
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-DomainRegistration -Domain google.com
        Get domain registration info for google.com
    .NOTES
        Status: Stable
        https://whois.whoisxmlapi.com/documentation/making-requests
        https://rdap.verisign.com/com/v1/domain/<DOMAIN>
        https://domainsrdap.googleapis.com/v1/domain/<DOMAIN>
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Target Domain')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Domain,

        [Parameter(Mandatory, HelpMessage = 'API Key')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ApiKey
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        $baseUrl = 'https://www.whoisxmlapi.com/whoisserver/WhoisService?apiKey={0}&domainName={1}'
        $headers = @{ Accept = 'application/json' }
    }
    Process {
        $url = $baseUrl -f $ApiKey, $Domain

        Write-Verbose -Message ('Getting domain registration info for [{0}]' -f $Domain)

        try {
            Invoke-RestMethod -Uri $url -Headers $headers -Method 'GET'
        }
        catch {
            Write-Error -Message ('Error retrieving registration info for domain: {0}' -f $Domain)
        }
    }
}
