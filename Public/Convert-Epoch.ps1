function Convert-Epoch {
    <#
    .SYNOPSIS
        Convert epoch
    .DESCRIPTION
        Convert epoch to date/time or date/time to epoch
    .PARAMETER Date
        DateTime object
    .PARAMETER Seconds
        Epoch Time in seconds
    .PARAMETER Milliseconds
        Epoch Time in milliseconds
    .INPUTS
        System.DateTime.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Convert-Epoch -Seconds 1618614176
        Converts epoch time to date/time object
    .NOTES
        Status: Stable
    #>
    [CmdletBinding(DefaultParameterSetName = '__dt')]
    Param(
        [Parameter(Position = 0, ParameterSetName = '__dt', ValueFromPipeline, HelpMessage = 'DateTime object')]
        [ValidateNotNullOrEmpty()]
        [System.DateTime] $Date = (Get-Date),

        [Parameter(Mandatory, Position = 0, ParameterSetName = '__sc', HelpMessage = 'EPOCH Time in seconds')]
        [ValidateNotNullOrEmpty()]
        [System.Int64] $Seconds, # 1618614176

        [Parameter(Mandatory, Position = 0, ParameterSetName = '__ms', HelpMessage = 'EPOCH Time in milliseconds')]
        [ValidateNotNullOrEmpty()]
        [System.Int64] $Milliseconds # 1618614176000
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            '__dt' {
                [PSCustomObject] @{
                    Date         = $Date
                    Seconds      = [System.DateTimeOffset]::new($Date).ToUnixTimeSeconds()
                    Milliseconds = [System.DateTimeOffset]::new($Date).ToUnixTimeMilliseconds()
                }
            }
            '__sc' {
                [System.DateTimeOffset]::FromUnixTimeSeconds($Seconds).DateTime.ToLocalTime()
            }
            '__ms' {
                [System.DateTimeOffset]::FromUnixTimeMilliseconds($Milliseconds).DateTime.ToLocalTime()
            }
        }
    }
}
