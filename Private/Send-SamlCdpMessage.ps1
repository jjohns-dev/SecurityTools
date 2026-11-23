function Send-SamlCdpMessage {
    [CmdletBinding()]
    [OutputType([System.Int32])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Connected browser WebSocket')]
        [System.Net.WebSockets.WebSocket] $WebSocket,

        [Parameter(Mandatory, HelpMessage = 'Overall capture cancellation token')]
        [System.Threading.CancellationToken] $CancellationToken,

        [Parameter(Mandatory, HelpMessage = 'Invocation-local message-id state')]
        [System.Collections.Hashtable] $State,

        [Parameter(Mandatory, HelpMessage = 'CDP method name')]
        [System.String] $Method,

        [Parameter(HelpMessage = 'CDP method parameters')]
        [System.Collections.Hashtable] $Params = @{}
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $State.NextId++
        $json = @{
            id     = $State.NextId
            method = $Method
            params = $Params
        } | ConvertTo-Json -Compress -Depth 5
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $null = $WebSocket.SendAsync(
            [System.ArraySegment[System.Byte]] $bytes,
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $CancellationToken
        ).GetAwaiter().GetResult()
        $State.NextId
    }
}
