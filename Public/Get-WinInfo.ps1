function Get-WinInfo {
    <#
    .SYNOPSIS
        Get Windows information
    .DESCRIPTION
        Get Windows information using WMI and CIM
    .PARAMETER List
        List available classes
    .PARAMETER Id
        Id of class object
    .PARAMETER ComputerName
        Name of target host
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-WinInfo -List
        List available classes to pull information from
    .NOTES
        Status: Stable
        https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance
    #>
    [CmdletBinding(DefaultParameterSetName = '__list')]
    Param(
        [Parameter(Mandatory, HelpMessage = 'List available classes', ParameterSetName = '__list')]
        [System.Management.Automation.SwitchParameter] $List,

        [Parameter(Mandatory, HelpMessage = 'Class Id', ParameterSetName = '__info')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -GT 0 -and $_ -LE $InfoModel.Classes.Count })]
        [System.Int32] $Id,

        [Parameter(ValueFromPipeline, HelpMessage = 'Hostname of target computer', ParameterSetName = '__info')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Connection -ComputerName $_ -Count 1 -Quiet })]
        [Alias('CN')]
        [System.String] $ComputerName
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not $IsWindows) { Write-Error -Message 'Get-WinInfo requires Windows.' -ErrorAction Stop }

        # CREATE EVENT LIST
        $infoList = for ($i = 0; $i -LT $InfoModel.Classes.Count; $i++) {
            [PSCustomObject] @{
                Id        = ($i + 1)
                Namespace = $InfoModel.Classes[$i].Namespace
                ClassName = $InfoModel.Classes[$i].ClassName
                Filters   = $InfoModel.Classes[$i].Filters
                Comments  = $InfoModel.Classes[$i].Comments
            }
        }
    }
    Process {
        # LIST OR GET INFORMATION
        switch ($PSCmdlet.ParameterSetName) {
            '__list' {
                # LIST ALL INFORMATION MODEL OBJECTS
                $infoList | Format-Table -AutoSize
            }
            '__info' {
                # SET INFORMATION MODEL SELECTION
                $im = $InfoModel.Classes[($Id - 1)]

                # SET CIM PARAMETERS
                $cimParams = @{
                    Namespace = $im.Namespace
                    ClassName = $im.ClassName
                }

                # ADD FILTERS IF ANY
                if ( $im.Filters ) { $cimParams.Add('Filter', $im.Filters) }

                # ADD TARGET COMPUTER IF PROVIDED
                if ( $PSBoundParameters.ContainsKey('ComputerName') ) { $cimParams.Add('ComputerName', $ComputerName) }

                # GET CIM INFORMATION
                Get-CimInstance @cimParams
            }
        }
    }
}
