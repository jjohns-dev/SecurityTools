function Stop-SamlBrowserSession {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mandatory cleanup of resources owned by Get-SAMLResponse must not be skipped by WhatIf or Confirm.'
    )]
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Invocation-local resources to release')]
        [System.Collections.Hashtable] $Session
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $failures = [System.Collections.Generic.List[System.Management.Automation.ErrorRecord]]::new()
        foreach ($resource in @($Session.WebSocket, $Session.Cancellation)) {
            if ($resource) {
                try { $resource.Dispose() }
                catch { $failures.Add($PSItem) }
            }
        }
        if ($Session.Process) {
            try {
                if (-not $Session.Process.HasExited) { $Session.Process.Kill($true) }
            }
            catch { $failures.Add($PSItem) }
            try {
                if (-not $Session.Process.WaitForExit(5000)) {
                    Write-Error -Message 'The capture Edge process did not exit within five seconds.' -ErrorAction Stop
                }
            }
            catch { $failures.Add($PSItem) }
            try { $Session.Process.Dispose() }
            catch { $failures.Add($PSItem) }
        }
        if ($Session.ProfilePath -or $Session.LogPath) {
            Start-Sleep -Milliseconds 500
            foreach ($path in @($Session.ProfilePath, $Session.LogPath)) {
                if (-not $path) { continue }
                for ($attempt = 0; $attempt -lt 3; $attempt++) {
                    try {
                        if (Test-Path -LiteralPath $path) {
                            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
                        }
                        break
                    }
                    catch {
                        if ($attempt -eq 2) { $failures.Add($PSItem) }
                        else { Start-Sleep -Milliseconds 250 }
                    }
                }
            }
        }
        if ($failures.Count) {
            foreach ($failure in $failures) {
                Write-Warning -Message ('Could not release a SAML capture resource: {0}' -f $failure.Exception.Message)
            }
            Write-Error -Message 'SAML capture cleanup was incomplete; see the resource warnings.' -ErrorAction Stop
        }
    }
}
