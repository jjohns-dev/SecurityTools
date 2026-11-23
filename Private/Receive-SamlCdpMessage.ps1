function Receive-SamlCdpMessage {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Connected browser WebSocket')]
        [System.Net.WebSockets.WebSocket] $WebSocket,

        [Parameter(Mandatory, HelpMessage = 'Overall capture cancellation token')]
        [System.Threading.CancellationToken] $CancellationToken
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $buffer = [System.Byte[]]::new(65536)
        $stream = [System.IO.MemoryStream]::new()
        try {
            do {
                $result = $WebSocket.ReceiveAsync(
                    [System.ArraySegment[System.Byte]] $buffer, $CancellationToken
                ).GetAwaiter().GetResult()
                if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    Write-Error -Exception ([System.Net.WebSockets.WebSocketException]::new()) -ErrorAction Stop
                }
                $stream.Write($buffer, 0, $result.Count)
            } until ($result.EndOfMessage)
            [System.Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        finally {
            $stream.Dispose()
            Remove-Variable -Name 'buffer' -Force -ErrorAction Ignore
        }
    }
}
