function Get-ActiveGatewayUser {
    <#
    .SYNOPSIS
        Get users actively connected to the remote desktop gateway
    .DESCRIPTION
        This function shows users who have active connections through the
        remote desktop gateway provided.
    .PARAMETER ComputerName
        Remote desktop computer name
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-ActiveGWUser -CompuaterName Gateway
        Get all users connected through the RDGW "Gateway"
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    [Alias('Get-ActiveGWUser')]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Remote desktop gateway server' )]
        [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'CN', 'Computer', 'System', 'Target')]
        [System.String] $ComputerName
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not $IsWindows) { Write-Error -Message 'Get-ActiveGatewayUser requires Windows.' -ErrorAction Stop }

        # SET QUERY PARAMS
        $ParamHash = @{
            Class        = "Win32_TSGatewayConnection"
            Namespace    = "root\cimv2\TerminalServices"
            ComputerName = $ComputerName
            #Authentication = 6
        }

        # SET REGEX VARS
        $ConnTime = @('^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\.[\d-]+$', '$1-$2-$3 $4:$5:$6')
        $ConnDur = @('^\d{8}(\d{2})(\d{2})(\d{2})\.[\d:]+$', '$1:$2:$3')

        # SET PROPERTIES TO RETURN
        $PropertyList = @(
            'UserName'
            'ClientAddress'
            @{N = 'ConnectionTime'; E = { Get-Date ($_.ConnectedTime -Replace $ConnTime) } }
            @{N = 'ElapsedTime'; E = { ($_.ConnectionDuration -Replace $ConnDur) } }
            'ConnectedResource'
        )
    }
    Process {
        # GET DATA
        $Users = Get-CimInstance @ParamHash
    }
    End {
        # RETURN RESULTS WITH SELECTED PROPERTIES
        $Users | Select-Object -Property $PropertyList
    }
}
