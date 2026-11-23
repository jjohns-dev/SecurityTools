BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction Stop -Force
    }
}

BeforeAll {
    if (-not ('SamlTestWebSocket' -as [System.Type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public sealed class SamlTestWebSocket : WebSocket {
    public readonly Queue<string> Messages = new Queue<string>();
    public readonly List<string> Sent = new List<string>();
    public CancellationTokenSource CancelOnReceive;
    public bool ReturnClose;
    public int DisposeCount;
    public int ReceiveCount;
    public Uri ConnectedUri;
    public int ChunkSize = 8192;
    private byte[] current;
    private int offset;
    public override WebSocketCloseStatus? CloseStatus => null;
    public override string CloseStatusDescription => null;
    public override string SubProtocol => null;
    public override WebSocketState State => DisposeCount == 0 ? WebSocketState.Open : WebSocketState.Closed;
    public override void Abort() { }
    public override void Dispose() { DisposeCount++; }
    public Task ConnectAsync(Uri uri, CancellationToken token) {
        ConnectedUri = uri;
        return Task.CompletedTask;
    }
    public override Task CloseAsync(WebSocketCloseStatus status, string description, CancellationToken token) {
        return Task.CompletedTask;
    }
    public override Task CloseOutputAsync(WebSocketCloseStatus status, string description, CancellationToken token) {
        return Task.CompletedTask;
    }
    public override Task SendAsync(ArraySegment<byte> buffer, WebSocketMessageType type, bool end, CancellationToken token) {
        token.ThrowIfCancellationRequested();
        Sent.Add(Encoding.UTF8.GetString(buffer.Array, buffer.Offset, buffer.Count));
        return Task.CompletedTask;
    }
    public override Task<WebSocketReceiveResult> ReceiveAsync(ArraySegment<byte> buffer, CancellationToken token) {
        ReceiveCount++;
        if (CancelOnReceive != null) CancelOnReceive.Cancel();
        if (token.IsCancellationRequested) return Task.FromCanceled<WebSocketReceiveResult>(token);
        if (ReturnClose) {
            return Task.FromResult(new WebSocketReceiveResult(0, WebSocketMessageType.Close, true));
        }
        if (current == null) {
            if (Messages.Count == 0) {
                return Task.FromException<WebSocketReceiveResult>(new WebSocketException("Synthetic disconnect"));
            }
            current = Encoding.UTF8.GetBytes(Messages.Dequeue());
            offset = 0;
        }
        int count = Math.Min(Math.Min(ChunkSize, buffer.Count), current.Length - offset);
        Array.Copy(current, offset, buffer.Array, buffer.Offset, count);
        offset += count;
        bool end = offset == current.Length;
        if (end) current = null;
        return Task.FromResult(new WebSocketReceiveResult(count, WebSocketMessageType.Text, end));
    }
}
'@
    }
}

Describe -Name 'Get-SAMLResponse' -Fixture {
    BeforeEach {
        $fixture = @{
            Socket       = [SamlTestWebSocket]::new()
            Cancellation = [System.Threading.CancellationTokenSource]::new()
            ProfilePath  = Join-Path -Path $TestDrive -ChildPath 'capture-profile'
            LogPath      = Join-Path -Path $TestDrive -ChildPath 'capture-profile.log'
        }
        $fixture.Socket.Messages.Enqueue('{"id":1,"result":{}}')
        Set-Variable -Name 'captureParams' -Value @{
            LoginUri     = 'https://login.example.com/signin'
            AssertionUri = 'https://pam.example.com/*'
        }
        Mock -CommandName Get-SamlBrowserPath -ModuleName $env:BHProjectName -MockWith { 'mock-edge' }
        Mock -CommandName Start-SamlBrowserSession -ModuleName $env:BHProjectName -MockWith {
            $Session.WebSocket = $fixture.Socket
            $Session.Cancellation = $fixture.Cancellation
            $Session.ProfilePath = $fixture.ProfilePath
            $Session.LogPath = $fixture.LogPath
            $null = New-Item -Path $Session.ProfilePath -ItemType Directory
            $null = New-Item -Path $Session.LogPath -ItemType File
        }
        Mock -CommandName Start-Sleep -ModuleName $env:BHProjectName -MockWith {}
    }
    AfterEach {
        $fixture.Cancellation.Dispose()
    }
    It -Name 'returns only the decoded assertion and ignores unrelated traffic and form fields' -Test {
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"GET","url":"https://pam.example.com/acs","postData":"SAMLResponse=wrong"}}}')
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"POST","url":"https://other.example.com/acs","postData":"SAMLResponse=wrong"}}}')
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"POST","url":"https://pam.example.com/acs","postData":"NotSAMLResponse=wrong&RelayState=SAMLResponse=wrong"}}}')
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"POST","url":"https://pam.example.com/acs","headers":{"X-Test":"a","x-test":"b"},"postData":"RelayState=ignored&SAMLResponse=abc%2B%3D%2F&Other=ignored"}}}')
        $result = @(Get-SAMLResponse @captureParams -InformationVariable information)
        $result | Should -HaveCount 1
        $result[0] | Should -BeExactly 'abc+=/'
        $result[0] | Should -BeOfType ([System.String])
        $information.MessageData | Should -Match 'Complete sign-in'
        $fixture.Socket.DisposeCount | Should -Be 1
        Test-Path -LiteralPath $fixture.ProfilePath | Should -BeFalse
        Test-Path -LiteralPath $fixture.LogPath | Should -BeFalse
        $sent = $fixture.Socket.Sent | ConvertFrom-Json -AsHashtable
        $sent.method | Should -Be @('Network.enable', 'Page.navigate')
        $sent[1].params.url | Should -BeExactly $captureParams.LoginUri
    }
    It -Name 'retrieves an omitted body and waits for the matching reply id' -Test {
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"requestId":"request-42","request":{"method":"POST","url":"https://pam.example.com/acs","hasPostData":true}}}')
        $fixture.Socket.Messages.Enqueue('{"id":99,"result":{"postData":"SAMLResponse=wrong"}}')
        $fixture.Socket.Messages.Enqueue('{"method":"Network.loadingFinished","params":{"requestId":"request-42"}}')
        $fixture.Socket.Messages.Enqueue('{"id":3,"result":{"postData":"SAMLResponse=large%2B%2F%3D"}}')
        Get-SAMLResponse @captureParams | Should -BeExactly 'large+/='
        $command = $fixture.Socket.Sent[2] | ConvertFrom-Json -AsHashtable
        $command.method | Should -Be 'Network.getRequestPostData'
        $command.params.requestId | Should -Be 'request-42'
    }
    It -Name 'reassembles a large assertion split across receive buffers' -Test {
        $expected = ('abc+/=' * 30000)
        $message = @{
            method = 'Network.requestWillBeSent'
            params = @{
                request = @{
                    method   = 'POST'
                    url      = 'https://pam.example.com/acs'
                    postData = 'SAMLResponse={0}' -f [System.Uri]::EscapeDataString($expected)
                }
            }
        } | ConvertTo-Json -Depth 5 -Compress
        $fixture.Socket.Messages.Enqueue($message)
        Get-SAMLResponse @captureParams | Should -BeExactly $expected
        $fixture.Socket.ReceiveCount | Should -BeGreaterThan 3
    }
    It -Name 'starts the command id sequence afresh for each invocation' -Test {
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"POST","url":"https://pam.example.com/acs","postData":"SAMLResponse=one"}}}')
        Get-SAMLResponse @captureParams | Should -BeExactly 'one'
        ($fixture.Socket.Sent[0] | ConvertFrom-Json -AsHashtable).id | Should -Be 1
        $fixture.Socket = [SamlTestWebSocket]::new()
        $fixture.Cancellation = [System.Threading.CancellationTokenSource]::new()
        $fixture.Socket.Messages.Enqueue('{"id":1,"result":{}}')
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"POST","url":"https://pam.example.com/acs","postData":"SAMLResponse=two"}}}')
        Get-SAMLResponse @captureParams | Should -BeExactly 'two'
        ($fixture.Socket.Sent[0] | ConvertFrom-Json -AsHashtable).id | Should -Be 1
    }
    It -Name 'reports timeout distinctly and still disposes the WebSocket' -Test {
        $fixture.Socket.CancelOnReceive = $fixture.Cancellation
        { Get-SAMLResponse @captureParams -Timeout ([System.TimeSpan]::FromSeconds(7)) } |
            Should -Throw -ExpectedMessage 'Timed out waiting for the SAMLResponse (limit 00:00:07)'
        $fixture.Socket.DisposeCount | Should -Be 1
        Test-Path -LiteralPath $fixture.ProfilePath | Should -BeFalse
        Test-Path -LiteralPath $fixture.LogPath | Should -BeFalse
    }
    It -Name 'reports a dropped connection and still disposes the WebSocket' -Test {
        { Get-SAMLResponse @captureParams } |
            Should -Throw -ExpectedMessage 'Lost the connection to Edge before the SAMLResponse was captured (was the window closed?)'
        $fixture.Socket.DisposeCount | Should -Be 1
        Test-Path -LiteralPath $fixture.ProfilePath | Should -BeFalse
        Test-Path -LiteralPath $fixture.LogPath | Should -BeFalse
    }
    It -Name 'reports a WebSocket Close as a lost connection' -Test {
        $fixture.Socket.ReturnClose = $true
        { Get-SAMLResponse @captureParams } |
            Should -Throw -ExpectedMessage 'Lost the connection to Edge before the SAMLResponse was captured (was the window closed?)'
        $fixture.Socket.DisposeCount | Should -Be 1
    }
    It -Name 'reports an empty assertion without returning partial output' -Test {
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"request":{"method":"POST","url":"https://pam.example.com/acs","postData":"SAMLResponse="}}}')
        { Get-SAMLResponse @captureParams } | Should -Throw -ExpectedMessage 'SAMLResponse not found*'
        $fixture.Socket.DisposeCount | Should -Be 1
    }
    It -Name 'surfaces a CDP post-data error without exposing its contents' -Test {
        $fixture.Socket.Messages.Enqueue('{"method":"Network.requestWillBeSent","params":{"requestId":"42","request":{"method":"POST","url":"https://pam.example.com/acs","hasPostData":true}}}')
        $fixture.Socket.Messages.Enqueue('{"id":3,"error":{"message":"sensitive details"}}')
        { Get-SAMLResponse @captureParams } | Should -Throw -ExpectedMessage 'Edge could not retrieve the SAML POST body.'
        $fixture.Socket.DisposeCount | Should -Be 1
    }
    It -Name 'does not navigate if network capture could not be enabled' -Test {
        $fixture.Socket.Messages.Clear()
        $fixture.Socket.Messages.Enqueue('{"id":1,"error":{"message":"not enabled"}}')
        { Get-SAMLResponse @captureParams } | Should -Throw -ExpectedMessage 'Edge could not enable CDP network capture.'
        $fixture.Socket.Sent | Should -HaveCount 1
    }
    It -Name 'surfaces navigation errors without exposing sign-in details' -Test {
        $fixture.Socket.Messages.Enqueue('{"id":2,"result":{"errorText":"sensitive details"}}')
        { Get-SAMLResponse @captureParams } | Should -Throw -ExpectedMessage 'Edge could not navigate to the sign-in URI.'
    }
    It -Name 'reports a missing browser before startup' -Test {
        Mock -CommandName Get-SamlBrowserPath -ModuleName $env:BHProjectName -MockWith {
            Write-Error -Message 'Microsoft Edge not found.' -ErrorAction Stop
        }
        { Get-SAMLResponse @captureParams } | Should -Throw -ExpectedMessage '*Microsoft Edge not found*'
        Should -Invoke -CommandName Start-SamlBrowserSession -ModuleName $env:BHProjectName -Times 0 -Exactly
    }
    It -Name 'cleans up resources acquired before startup fails' -Test {
        Mock -CommandName Start-SamlBrowserSession -ModuleName $env:BHProjectName -MockWith {
            $Session.WebSocket = $fixture.Socket
            $Session.Cancellation = $fixture.Cancellation
            Write-Error -Message 'Synthetic startup failure' -ErrorAction Stop
        }
        { Get-SAMLResponse @captureParams } | Should -Throw -ExpectedMessage 'Synthetic startup failure'
        $fixture.Socket.DisposeCount | Should -Be 1
    }
    It -Name 'rejects invalid input without starting a browser' -Test {
        { Get-SAMLResponse @captureParams -Timeout ([System.TimeSpan]::Zero) } | Should -Throw
        { Get-SAMLResponse -LoginUri '/relative' -AssertionUri '*' } | Should -Throw
        Should -Invoke -CommandName Start-SamlBrowserSession -ModuleName $env:BHProjectName -Times 0 -Exactly
    }
}

Describe -Name 'SAML browser discovery and lifecycle' -Fixture {
    BeforeEach {
        $fixture = @{
            Process = [PSCustomObject] @{
                HasExited = $false
                Killed    = $false
                Waited    = $false
                Disposed  = $false
            }
        }
        $fixture.Process | Add-Member -MemberType ScriptMethod -Name Kill -Value {
            param($entireTree)
            $this.Killed = $entireTree
            $this.HasExited = $true
        }
        $fixture.Process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
            param($milliseconds)
            $this.Waited = $milliseconds -eq 5000
            $true
        }
        $fixture.Process | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.Disposed = $true }
        Mock -CommandName Start-Sleep -ModuleName $env:BHProjectName -MockWith {}
        Mock -CommandName Start-Process -ModuleName $env:BHProjectName -MockWith { $fixture.Process }
    }
    It -Name 'uses an explicit browser path without falling back to discovery' -Test {
        $browser = Join-Path -Path $TestDrive -ChildPath 'mock-edge'
        $null = New-Item -Path $browser -ItemType File
        InModuleScope -ModuleName $env:BHProjectName -Parameters @{ Browser = $browser } -ScriptBlock {
            Get-SamlBrowserPath -BrowserPath $Browser | Should -Be $Browser
            { Get-SamlBrowserPath -BrowserPath ('{0}-missing' -f $Browser) } |
                Should -Throw -ExpectedMessage '*Microsoft Edge not found*'
        }
    }
    It -Name 'reports no browser when platform discovery finds no files' -Test {
        Mock -CommandName Test-Path -ModuleName $env:BHProjectName -MockWith { $false }
        Mock -CommandName Get-Command -ModuleName $env:BHProjectName -MockWith { $null } -ParameterFilter {
            $Name -eq 'microsoft-edge'
        }
        InModuleScope -ModuleName $env:BHProjectName -ScriptBlock {
            { Get-SamlBrowserPath } | Should -Throw -ExpectedMessage '*Microsoft Edge not found*'
        }
    }
    It -Name 'stops polling when no blank page target appears before the deadline' -Test {
        $clock = @{ Now = [System.DateTime]::UtcNow }
        $started = $clock.Now
        Mock -CommandName Get-Date -ModuleName $env:BHProjectName -MockWith {
            $clock.Now
        }
        Mock -CommandName Start-Sleep -ModuleName $env:BHProjectName -MockWith {
            $clock.Now = $clock.Now.AddMilliseconds($Milliseconds)
        }
        Mock -CommandName Test-Path -ModuleName $env:BHProjectName -MockWith { $true }
        Mock -CommandName Get-Content -ModuleName $env:BHProjectName -MockWith { '9222' }
        Mock -CommandName Invoke-RestMethod -ModuleName $env:BHProjectName -MockWith {
            ,@(
                [PSCustomObject] @{ type = 'worker'; url = 'about:blank' }
                [PSCustomObject] @{ type = 'page'; url = 'https://other.example.com/' }
            )
        }
        InModuleScope -ModuleName $env:BHProjectName -ScriptBlock {
            $session = @{}
            try {
                { Start-SamlBrowserSession -Session $session -BrowserPath 'mock-edge' -Timeout ([System.TimeSpan]::FromMinutes(5)) } |
                    Should -Throw -ExpectedMessage '*did not expose a DevTools page target*'
            }
            finally {
                $session.WebSocket.Dispose()
                $session.Cancellation.Dispose()
            }
        }
        Should -Invoke -CommandName Invoke-RestMethod -ModuleName $env:BHProjectName -Times 1
        ($clock.Now - $started) | Should -Be ([System.TimeSpan]::FromSeconds(20))
        Should -Invoke -CommandName Start-Process -ModuleName $env:BHProjectName -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -contains '--remote-debugging-port=0' -and
            $ArgumentList -contains 'about:blank' -and
            $ArgumentList[0] -like '--user-data-dir="*"' -and
            $RedirectStandardError -like '*.log'
        }
    }
    It -Name 'selects the blank page from a target array without opening a socket' -Test {
        Mock -CommandName Test-Path -ModuleName $env:BHProjectName -MockWith { $true }
        Mock -CommandName Get-Content -ModuleName $env:BHProjectName -MockWith { '9222' }
        Mock -CommandName Invoke-RestMethod -ModuleName $env:BHProjectName -MockWith {
            ,@(
                [PSCustomObject] @{ type = 'worker'; url = 'about:blank'; webSocketDebuggerUrl = 'ws://127.0.0.1:9222/wrong' }
                [PSCustomObject] @{ type = 'page'; url = 'https://other.example.com/'; webSocketDebuggerUrl = 'ws://127.0.0.1:9222/other' }
                [PSCustomObject] @{ type = 'page'; url = 'about:blank'; webSocketDebuggerUrl = 'ws://127.0.0.1:9222/right' }
            )
        }
        InModuleScope -ModuleName $env:BHProjectName -ScriptBlock {
            $session = @{ WebSocket = [SamlTestWebSocket]::new() }
            try {
                @(Start-SamlBrowserSession -Session $session -BrowserPath 'mock-edge' -Timeout ([System.TimeSpan]::FromMinutes(5))) |
                    Should -HaveCount 0
                $session.WebSocket.ConnectedUri.AbsoluteUri | Should -Be 'ws://127.0.0.1:9222/right'
            }
            finally {
                $session.WebSocket.Dispose()
                $session.Cancellation.Dispose()
            }
        }
    }
    It -Name 'removes the owned profile and log and terminates the owned process tree' -Test {
        $profilePath = Join-Path -Path $TestDrive -ChildPath 'owned-profile'
        $log = '{0}.log' -f $profilePath
        $null = New-Item -Path $profilePath -ItemType Directory
        $null = New-Item -Path (Join-Path -Path $profilePath -ChildPath 'locked-data') -ItemType File
        $null = New-Item -Path $log -ItemType File
        $session = @{
            Process      = $fixture.Process
            WebSocket    = [SamlTestWebSocket]::new()
            Cancellation = [System.Threading.CancellationTokenSource]::new()
            ProfilePath  = $profilePath
            LogPath      = $log
        }
        InModuleScope -ModuleName $env:BHProjectName -Parameters @{ Session = $session } -ScriptBlock {
            @(Stop-SamlBrowserSession -Session $Session) | Should -HaveCount 0
        }
        $fixture.Process.Killed | Should -BeTrue
        $fixture.Process.Waited | Should -BeTrue
        $fixture.Process.Disposed | Should -BeTrue
        $session.WebSocket.DisposeCount | Should -Be 1
        Test-Path -LiteralPath $profilePath | Should -BeFalse
        Test-Path -LiteralPath $log | Should -BeFalse
    }
    It -Name 'continues file cleanup when process termination fails and reports the failure' -Test {
        $fixture.Process | Add-Member -MemberType ScriptMethod -Name Kill -Force -Value {
            param($entireTree)
            Write-Error -Message ('Synthetic kill failure (tree={0})' -f $entireTree) -ErrorAction Stop
        }
        $profilePath = Join-Path -Path $TestDrive -ChildPath 'error-profile'
        $log = '{0}.log' -f $profilePath
        $null = New-Item -Path $profilePath -ItemType Directory
        $null = New-Item -Path $log -ItemType File
        $session = @{ Process = $fixture.Process; ProfilePath = $profilePath; LogPath = $log }
        InModuleScope -ModuleName $env:BHProjectName -Parameters @{ Session = $session } -ScriptBlock {
            { Stop-SamlBrowserSession -Session $Session -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*cleanup was incomplete*'
        }
        $fixture.Process.Waited | Should -BeTrue
        Test-Path -LiteralPath $profilePath | Should -BeFalse
        Test-Path -LiteralPath $log | Should -BeFalse
    }
}
