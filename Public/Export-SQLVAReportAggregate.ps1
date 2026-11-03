#Requires -Modules ImportExcel
function Export-SQLVAReportAggregate {
    <#
    .SYNOPSIS
        Aggregate results from SQL Vulnerability Assessment scans
    .DESCRIPTION
        Aggregate results from SQL Vulnerability Assessment scans into a single report
    .PARAMETER InputPath
        Path to directory of SQL Vulnerability Assessemnt file(s)
    .PARAMETER ZipPath
        Path to zip file containing repots
    .PARAMETER DestinationPath
        Path to output report file
    .PARAMETER PassThru
        Return report path
    .INPUTS
        None.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Export-SQLVAReportAggregate -InputPath (Get-ChildItem C:\MyScans).FullName
        Combine all scans in C:\MyScans folder into a single report and output to the desktop.
    .NOTES
        Status: Stable
    #>
    [CmdletBinding(DefaultParameterSetName = 'folder')]
    Param(
        [Parameter(
            Mandatory, ParameterSetName = 'folder',
            HelpMessage = 'Path to directory of SQL Vulnerability Assessemnt file(s)'
        )]
        [ValidateScript({ Test-Path -Path (Join-Path -Path $_ -ChildPath '*') -Include '*.xlsx' })]
        [Alias('IP', 'Directory')]
        [System.String] $InputPath,

        [Parameter(
            Mandatory, ParameterSetName = 'zip',
            HelpMessage = 'Path to zip file containing reports'
        )]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.zip" })]
        [Alias('Zip', 'ZP')]
        [System.String] $ZipPath,

        [Parameter(HelpMessage = 'Path to output report file')]
        [ValidateScript({ Test-Path -Path ([System.IO.Path]::GetDirectoryName($_)) })]
        [ValidateScript({ [System.IO.Path]::GetExtension($_) -eq '.xlsx' })]
        [Alias('DP')]
        [System.String] $DestinationPath,

        [Parameter(HelpMessage = 'Return path to aggreate report')]
        [System.Management.Automation.SwitchParameter] $PassThru
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # IMPORT REQUIRED MODULE
        Import-Module -Name ImportExcel

        # CREATE ARRAY
        $Data = [System.Collections.Generic.List[System.Object]]::new()

        # WRITE TO DESKTOP IF DESTINATIONPATH NOT PROVIDED
        if ( -not $PSBoundParameters.ContainsKey('DestinationPath') ) {
            $DestinationPath = Join-Path -Path (Join-Path -Path $HOME -ChildPath 'Desktop') -ChildPath ('Aggregate-SQL-Scans_{0:yyyy-MM}.xlsx' -f (Get-Date))
        }

        # GET REPORTS FROM ZIP
        if ( $PSBoundParameters.ContainsKey('ZipPath') ) {
            # EXTRACT FILES
            Expand-Archive -Path $ZipPath -DestinationPath ($ExpandPath = (Join-Path -Path (Join-Path -Path $HOME -ChildPath 'Desktop') -ChildPath 'Extract'))

            # RESET INPUTPATH VAR
            $InputPath = $ExpandPath
        }

        # GET REPORTS FROM FOLDER
        $ReportFiles = Get-ChildItem -Path ('{0}\*.xlsx' -f $InputPath)
    }

    Process {
        # LOOP THROUGH ALL PROVIDED REPORTS
        foreach ( $Report in $ReportFiles.FullName ) {
            # ADD ALL FAILED STATUS TO ARRAY
            foreach ( $o in (Import-Excel -Path $Report -StartRow 8 -WorksheetName Results) ) {
                if ( $o.Status -ne 'Pass' ) { $Data.Add($o) }
            }
        }
    }

    End {
        # SET EXCEL PARAMS
        $ExcelParams = @{
            AutoFilter    = $true
            BoldTopRow    = $true
            FreezeTopRow  = $true
            MoveToEnd     = $true
            Path          = $DestinationPath
            WorksheetName = 'DBScan'
            Style         = (New-ExcelStyle -Bold -Range '1:1' -HorizontalAlignment Center)
        }

        # EXPORT NEW AGGREATE REPORT
        $Data | Export-Excel @ExcelParams

        # RETURN PATH TO REPORT
        if ( $PSBoundParameters.ContainsKey('PassThru') ) { Write-Output -InputObject $DestinationPath }

        # REMOVE EXTRACTED FILES
        if ( $ExpandPath ) { Remove-Item -Path $InputPath -Recurse -Force }
    }
}
