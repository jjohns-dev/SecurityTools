function Start-SamlBrowserSession {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal startup is required for Get-SAMLResponse; skipping it cannot produce a capture session.'
    )]
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Invocation-local resource state, updated as resources are acquired')]
        [System.Collections.Hashtable] $Session,

        [Parameter(Mandatory, HelpMessage = 'Installed Microsoft Edge executable')]
        [System.String] $BrowserPath,

        [Parameter(Mandatory, HelpMessage = 'Overall capture time limit')]
        [System.TimeSpan] $Timeout
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $Session.Cancellation = [System.Threading.CancellationTokenSource]::new($Timeout)
        $Session.ProfilePath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (
            'securitytools-saml-{0}' -f (New-Guid)
        )
        $Session.LogPath = '{0}.log' -f $Session.ProfilePath
        if (-not $Session.WebSocket) {
            $Session.WebSocket = [System.Net.WebSockets.ClientWebSocket]::new()
        }
        $startParams = @{
            FilePath              = $BrowserPath
            ArgumentList          = @(
                ('--user-data-dir="{0}"' -f $Session.ProfilePath)
                '--remote-debugging-port=0'
                '--no-first-run'
                '--no-default-browser-check'
                'about:blank'
            )
            RedirectStandardError = $Session.LogPath
            PassThru              = $true
            ErrorAction           = 'Stop'
        }
        $deadline = (Get-Date).AddSeconds([System.Math]::Min(20, $Timeout.TotalSeconds))
        $Session.Process = Start-Process @startParams
        $portFile = Join-Path -Path $Session.ProfilePath -ChildPath 'DevToolsActivePort'
        $target = $null
        while (-not $target -and (Get-Date) -lt $deadline) {
            $Session.Cancellation.Token.ThrowIfCancellationRequested()
            if ($Session.Process.HasExited) {
                Write-Error -Exception ([System.Net.WebSockets.WebSocketException]::new()) -ErrorAction Stop
            }
            if (Test-Path -LiteralPath $portFile) {
                $portText = Get-Content -LiteralPath $portFile -TotalCount 1 -ErrorAction Stop
                $port = 0
                if ([System.Int32]::TryParse($portText, [ref] $port) -and $port -ge 1 -and $port -le 65535) {
                    $remaining = ($deadline - (Get-Date)).TotalSeconds
                    if ($remaining -lt 1) {
                        if ($remaining -gt 0) {
                            Start-Sleep -Milliseconds ([System.Int32] [System.Math]::Ceiling($remaining * 1000))
                        }
                        continue
                    }
                    try {
                        $restParams = @{
                            Uri         = 'http://127.0.0.1:{0}/json/list' -f $port
                            TimeoutSec  = [System.Int32] [System.Math]::Floor($remaining)
                            ErrorAction = 'Stop'
                        }
                        $target = (Invoke-RestMethod @restParams) |
                            Where-Object -FilterScript { $_.type -eq 'page' -and $_.url -eq 'about:blank' } |
                            Select-Object -First 1
                    }
                    catch [System.Net.Http.HttpRequestException], [System.Net.WebException],
                        [System.TimeoutException], [System.Threading.Tasks.TaskCanceledException] {
                        Write-Verbose -Message 'Waiting for the local Edge DevTools endpoint to become ready.'
                    }
                }
            }
            if (-not $target) {
                $remainingMilliseconds = ($deadline - (Get-Date)).TotalMilliseconds
                if ($remainingMilliseconds -gt 0) {
                    Start-Sleep -Milliseconds ([System.Int32] [System.Math]::Min(250, $remainingMilliseconds))
                }
            }
        }
        $Session.Cancellation.Token.ThrowIfCancellationRequested()
        if (-not $target) {
            Write-Error -Message 'Edge did not expose a DevTools page target within 20 seconds or the configured timeout.' -ErrorAction Stop
        }
        $null = $Session.WebSocket.ConnectAsync(
            [System.Uri] $target.webSocketDebuggerUrl, $Session.Cancellation.Token
        ).GetAwaiter().GetResult()
    }
}
