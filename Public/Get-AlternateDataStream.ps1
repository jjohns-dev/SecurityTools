function Get-AlternateDataStream {
    <#
    .SYNOPSIS
        Get alternate data streams
    .DESCRIPTION
        Get alternate data streams
    .PARAMETER Path
        File path
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-AlternateDataStream -Path .\*.db

        Path                 Stream     Size
        ----                 ------     ----
        C:\work\inventory.db LastUpdate   22
        C:\work\tickle.db    LastUpdate   22
        C:\work\vm.db        secret       18

        Gets alternate data streams from all files in current directory with extension .db
    .NOTES
        Status: Stable
        https://jdhitsolutions.com/blog/scripting/8888/friday-fun-with-powershell-and-alternate-data-streams/

        Zone.Identifiers
        0 = Local computer
        1 = Local intranet
        2 = Trusted sites
        3 = Internet
        4 = Restricted sites
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(ValueFromPipeline, Position = 0, HelpMessage = 'File path')]
        #[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [ValidateNotNullOrEmpty()]
        [System.String] $Path = "*.*"
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # SET DESIRED PROPERTIES
        $props = @(
            @{ Name = "Path"; Expression = { $_.FileName } }
            'Stream'
            @{ Name = "Size"; Expression = { $_.Length } }
        )

        # SET WHERE STATEMENT
        $where = { $_.Stream -ne ':$DATA' }
    }
    Process {
        # GET ALTERNATE DATA STREAM(S)
        Get-Item -Path $Path -Stream * | Where-Object $where | Select-Object $props
    }
}
