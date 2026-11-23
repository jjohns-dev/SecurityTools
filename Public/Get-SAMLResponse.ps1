function Get-SAMLResponse {
    <#
    .SYNOPSIS
        Capture a SAMLResponse from an interactive Microsoft Edge sign-in.
    .DESCRIPTION
        Opens locally installed Microsoft Edge with a temporary profile and captures the SAMLResponse form field
        posted to the matching assertion URL. Complete sign-in and MFA in the visible browser window.
        Uses built-in .NET WebSockets and the Chrome DevTools Protocol; no browser downloads or extra dependencies.
        The POST is observed, not blocked. The returned assertion is sensitive and should not be logged.
    .PARAMETER LoginUri
        Absolute identity-provider sign-in URI to open.
    .PARAMETER AssertionUri
        PowerShell wildcard pattern for the service-provider URL receiving the SAML POST.
    .PARAMETER Timeout
        Overall time limit for browser startup, interactive sign-in, and capture. Defaults to five minutes.
        Browser startup is additionally limited to 20 seconds. Cleanup runs outside this limit.
    .PARAMETER BrowserPath
        Path to an installed Microsoft Edge executable. Overrides platform-specific discovery.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The URL-decoded SAMLResponse form field.
    .EXAMPLE
        PS C:\> $assertion = Get-SAMLResponse -LoginUri 'https://login.example.com/signin' -AssertionUri 'https://pam.example.com/*' -InformationAction Continue
        Complete sign-in in Edge and store the decoded assertion without status text in the result.
    .EXAMPLE
        PS C:\> Get-SAMLResponse -LoginUri 'https://login.example.com/signin' -AssertionUri 'https://pam.example.com/*' -Timeout (New-TimeSpan -Minutes 10)
        Allow up to ten minutes for startup, sign-in, and MFA.
    .NOTES
        Status: Beta
        While open, Edge exposes DevTools on a random port bound to 127.0.0.1. In the reported reference testing,
        Edge rejected non-local Host headers and WebSocket connections with a foreign Origin (403), preventing
        those web-page/DNS-rebinding approaches. These checks do not protect against local processes, including
        other users' processes, which can connect during capture. Managed Edge may silently sign the temporary
        profile in to a work account; a connected local process could act with that session.
        Playwright avoids this exposure with --remote-debugging-pipe. This function accepts a short-lived
        localhost port to remain dependency-free. The browser is terminated and its temporary profile deleted
        afterwards. Chromium 136+ requires a non-default profile for remote debugging.
        https://developer.chrome.com/blog/remote-debugging-port
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Absolute identity-provider sign-in URI')]
        [ValidateScript({ $_.IsAbsoluteUri })]
        [System.Uri] $LoginUri,

        [Parameter(Mandatory, HelpMessage = 'Wildcard pattern for the SAML POST destination URL')]
        [ValidateNotNullOrEmpty()]
        [System.String] $AssertionUri,

        [Parameter(HelpMessage = 'Time limit for browser startup and interactive sign-in')]
        [ValidateScript({ $_ -gt [System.TimeSpan]::Zero -and $_.TotalMilliseconds -le [System.UInt32]::MaxValue - 1 })]
        [System.TimeSpan] $Timeout = (New-TimeSpan -Minutes 5),

        [Parameter(HelpMessage = 'Override the installed Microsoft Edge executable path')]
        [ValidateNotNullOrEmpty()]
        [System.String] $BrowserPath
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $session = @{
            Process      = $null
            WebSocket    = $null
            Cancellation = $null
            ProfilePath  = $null
            LogPath      = $null
            NextId       = 0
        }
        $captureFailed = $false
        try {
            $edgePath = Get-SamlBrowserPath -BrowserPath $BrowserPath
            Start-SamlBrowserSession -Session $session -BrowserPath $edgePath -Timeout $Timeout
            $transportParams = @{
                WebSocket         = $session.WebSocket
                CancellationToken = $session.Cancellation.Token
            }
            $enableId = Send-SamlCdpMessage @transportParams -State $session -Method 'Network.enable'
            do {
                $message = Receive-SamlCdpMessage @transportParams
                if ($message.id -eq $enableId -and $message.error) {
                    Write-Error -Message 'Edge could not enable CDP network capture.' -ErrorAction Stop
                }
            } until ($message.id -eq $enableId)
            $navigateId = Send-SamlCdpMessage @transportParams -State $session -Method 'Page.navigate' -Params @{
                url = $LoginUri.AbsoluteUri
            }
            Write-Information -MessageData 'Complete sign-in (including MFA) in the Edge window; SAML capture is automatic.'

            $samlResponse = $null
            while ($null -eq $samlResponse) {
                $message = Receive-SamlCdpMessage @transportParams
                if ($message.id -eq $navigateId -and ($message.error -or $message.result.errorText)) {
                    Write-Error -Message 'Edge could not navigate to the sign-in URI.' -ErrorAction Stop
                }
                if ($message.method -ne 'Network.requestWillBeSent') { continue }
                $request = $message.params.request
                if ($request.method -ne 'POST' -or $request.url -notlike $AssertionUri) { continue }

                $postData = $request.postData
                if (-not $postData -and $request.hasPostData) {
                    $replyId = Send-SamlCdpMessage @transportParams -State $session -Method 'Network.getRequestPostData' -Params @{
                        requestId = $message.params.requestId
                    }
                    do {
                        $reply = Receive-SamlCdpMessage @transportParams
                    } until ($reply.id -eq $replyId)
                    if ($reply.error) {
                        Write-Error -Message 'Edge could not retrieve the SAML POST body.' -ErrorAction Stop
                    }
                    $postData = $reply.result.postData
                }
                foreach ($field in ($postData -split '&')) {
                    if ($field.StartsWith('SAMLResponse=', [System.StringComparison]::Ordinal)) {
                        $encoded = $field.Substring('SAMLResponse='.Length)
                        if ([System.String]::IsNullOrWhiteSpace($encoded)) {
                            Write-Error -Message 'SAMLResponse not found in the captured request' -ErrorAction Stop
                        }
                        $samlResponse = [System.Uri]::UnescapeDataString($encoded)
                        break
                    }
                }
            }
        }
        catch {
            $captureFailed = $true
            if ($session.Cancellation -and $session.Cancellation.IsCancellationRequested) {
                Write-Error -Message ('Timed out waiting for the SAMLResponse (limit {0})' -f $Timeout) -ErrorAction Stop
            }
            if ($PSItem.Exception.GetBaseException() -is [System.Net.WebSockets.WebSocketException]) {
                Write-Error -Message 'Lost the connection to Edge before the SAMLResponse was captured (was the window closed?)' -ErrorAction Stop
            }
            Write-Error -ErrorRecord $PSItem -ErrorAction Stop
        }
        finally {
            try {
                Stop-SamlBrowserSession -Session $session
            }
            catch {
                if ($captureFailed) {
                    Write-Warning -Message ('SAML capture cleanup failed: {0}' -f $PSItem.Exception.Message)
                }
                else {
                    Write-Error -ErrorRecord $PSItem -ErrorAction Stop
                }
            }
            finally {
                Remove-Variable -Name 'postData', 'encoded', 'field', 'message', 'reply', 'request' -Force -ErrorAction Ignore
            }
        }
        $samlResponse
        Remove-Variable -Name 'samlResponse' -Force -ErrorAction Ignore
    }
}
