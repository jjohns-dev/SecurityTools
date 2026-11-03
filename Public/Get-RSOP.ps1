function Get-RSOP {
    <#
    .SYNOPSIS
        Generate a Resultant Set of Policy report
    .DESCRIPTION
        Generate a Resultant Set of Policy report
    .PARAMETER Path
        Path to report file
    .PARAMETER Computer
        Target computer name
    .PARAMETER ReportType
        Report type output
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-RSOP
        Generate a Resultant Set of Policy report for the local system
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to report file')]
        [ValidateScript({ Test-Path -Path ([System.IO.Path]::GetDirectoryName($_)) -PathType Container })]
        [System.String] $Path,

        [Parameter(ValueFromPipeline, HelpMessage = 'Computer name')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Computer,

        [Parameter(HelpMessage = 'Report type output')]
        [ValidateSet('HTML', 'XML')]
        [System.String] $ReportType = 'HTML'
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        Import-Module -Name GroupPolicy -ErrorAction Stop
    }
    Process {
        if (!$PSBoundParameters.ContainsKey('ReportType')) { $PSBoundParameters.Add('ReportType', $ReportType) }
        Get-GPResultantSetOfPolicy @PSBoundParameters
    }
}
