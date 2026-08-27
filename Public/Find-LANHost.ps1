function Find-LANHost {
    <#
    .SYNOPSIS
        Find LAN hosts
    .DESCRIPTION
        Find LAN hosts
    .PARAMETER IP
        IP addresses to scan
    .PARAMETER DelayMS
        Delay in milliseconds between packet send
    .PARAMETER ClearARPCache
        Clear ARP cache before scanning
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> $ips = 1..254 | ForEach-Object { "10.250.1.$_" }; Find-LANHost -IP $ips
        Scans all 254 hosts on the 10.250.1.0/24 subnet and returns those with active ARP entries.
    .NOTES
        Status: Stable
        https://xkln.net/blog/layer-2-host-discovery-with-powershell-in-under-a-second/
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, Position = 1, HelpMessage = 'IP addresses to scan')]
        [System.String[]] $IP,

        [Parameter(Position = 2, HelpMessage = 'Delay in milliseconds between packet send')]
        [ValidateRange(0, 15000)]
        [System.Int32] $DelayMS = 2,

        [Parameter(HelpMessage = 'Clear ARP cache before scanning')]
        [ValidateScript({
                $IsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                if ($IsAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                    $True
                }
                else {
                    Write-Error -Message 'Must be running an elevated prompt to use ClearARPCache' -ErrorAction Stop
                }
            })]
        [System.Management.Automation.SwitchParameter] $ClearARPCache
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
        $Bytes = $ASCIIEncoding.GetBytes("a")
        $UDP = New-Object System.Net.Sockets.Udpclient

        if ($ClearARPCache) { arp -d }

        $Timer = [System.Diagnostics.Stopwatch]::StartNew()

        foreach ( $i in $IP ) {
            $UDP.Connect($i, 1)
            [void] $UDP.Send($Bytes, $Bytes.length)
            if ( $DelayMS ) { [System.Threading.Thread]::Sleep($DelayMS) }
        }

        $Hosts = arp -a

        $Timer.Stop()
        if ($Timer.Elapsed.TotalSeconds -gt 15) {
            Write-Warning "Scan took longer than 15 seconds, ARP entries may have been flushed. Recommend lowering DelayMS parameter"
        }

        $Hosts = $Hosts | Where-Object { $_ -match "dynamic" } | ForEach-Object { ($_.trim() -replace " {1,}", ",") | ConvertFrom-Csv -Header "IP", "MACAddress" }
        $Hosts = $Hosts | Where-Object { $_.IP -in $IP }

        Write-Output -InputObject $Hosts
    }
    End {
        if ($UDP) { $UDP.Dispose() }
    }
}
