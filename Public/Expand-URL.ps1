function Expand-URL {
    <#
    .SYNOPSIS
        Expand URL
    .DESCRIPTION
        Expand shortened URL
    .PARAMETER URL
        URL to expand
    .PARAMETER ApiKey
        API Key
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Expand-URL -URL 'https://tinyurl.com/example'
        Show destination URL target for a shortened or redirected URL
    .NOTES
        Status: Stable
        https://onesimpleapi.com/docs/url-unshorten
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'URL to expand')]
        [ValidateNotNullOrEmpty()]
        [System.Uri] $URL,

        [Parameter(Mandatory, HelpMessage = 'API Key')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ApiKey
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        # SET REQUEST PARAMETERS
        $restParams = @{
            Uri    = 'https://onesimpleapi.com/api/unshorten'
            Method = 'POST'
            Body   = @{
                token  = $ApiKey
                output = 'json'
                url    = $URL
            }
        }

        # SEND REQUEST
        Invoke-RestMethod @restParams
    }
}
