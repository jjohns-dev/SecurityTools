#Requires -Modules ImportExcel
function Export-ScanReportAggregate {
    <#
    .SYNOPSIS
        Aggregate and merge scan results into a single report
    .DESCRIPTION
        This function takes a web scan and system scan report and applies
        standard filters and columns to each for easy review in a single
        spreadsheet with multiple tabs.
    .PARAMETER OutputDirectory
        Path to output directory
    .PARAMETER NessusSystemScan
        Path to CSV file for Nessus system scan report
    .PARAMETER NessusWebScan
        Path to CSV file for Nessus web scan report
    .PARAMETER AlertLogicWebScan
        Path to CSV file for AlertLogic web scan report
    .PARAMETER DatabaseScan
        Path to XLSX file for SQL scan report
    .PARAMETER AcunetixScan
        Path to CSV file for Acunetix scan report
    .INPUTS
        System.String. Format-ScanResults accepts string values for SystemScan
        and AlertLogicWebScan parameters.
    .OUTPUTS
        Com.Excel.Application. Format-ScanResults returns an Excel spreadsheet
    .EXAMPLE
        PS C:\> Export-ScanReportAggregate -SystemScan $Sys -AlertLogicWebScan $Web
        Merge and aggregate data from $Sys and $Web scans into a pre-filtered
        report for easy review.
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [Alias('DestinationPath')]
        [System.String] $OutputDirectory = (Join-Path -Path $HOME -ChildPath 'Desktop'),

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.csv" })]
        [Alias('NessusScan')]
        [System.String] $NessusSystemScan,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.csv" })]
        [System.String] $NessusWebScan,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.csv" })]
        [System.String] $AlertLogicWebScan,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.xlsx" })]
        [System.String] $DatabaseScan,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.csv" })]
        [System.String] $AcunetixScan
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # PROVIDE HELP FOR THE USER WHEN NO SCANS ARE DECLARED
        $requiredParams = @('NessusSystemScan', 'NessusWebScan', 'AlertLogicWebScan', 'DatabaseScan', 'AcunetixScan')
        foreach ( $param in $requiredParams ) {
            if ( $param -notin $PSBoundParameters.Keys ) { $fail = $true } else { $fail = $false; break }
        }
        if ( $fail ) {
            Write-Error -Message 'Missing scan reports to aggregate. Please provide at least one scan report.' -ErrorAction Stop
        }

        # SET VARS
        $alProperties = @(
            'IP-address'
            'Detected Hostname'
            'Port number'
            'Exposure ID'
            'Name'
            'Protocol'
            'Service Description'
            'Severity'
            'CVSS'
            'Description'
            'Impact'
            'Resolution'
            'Evidence'
            'References'
            @{ Name = 'Status'; Expression = { $_.'Active or inactive' } }
        )

        $authWebProps = @(
            'Name'
            'ModuleName'
            'Details'
            'Parameter'
            'IsFalsePositive'
            'Severity'
            'Type'
            'Impact'
            'Description'
            'Detailed Information'
            'Recommendation'
            'Request'
            'CWEList'
            'CVEList'
            'CVSS Score'
            'CVSS3 Score'
            @{ Name = 'Reference'; Expression = { $_.'Reference (Name|Url' } }
        )

        # SET REPORT OPTIONS
        $excelParams = @{
            #AutoSize      = $true
            AutoFilter   = $true
            FreezeTopRow = $true
            BoldTopRow   = $true
            MoveToEnd    = $true
            Style        = (New-ExcelStyle -Bold -Range '1:1' -HorizontalAlignment Center)
            Path         = Join-Path -Path $OutputDirectory -ChildPath ('Aggregate-Scans_{0:yyyy-MM}.xlsx' -f (Get-Date))
        }
    }

    Process {
        # PROCESS INDIVIDUAL SCAN DATA
        if ( $PSBoundParameters.ContainsKey('AlertLogicWebScan') ) {
            $webCsv = Import-Csv -Path $AlertLogicWebScan
            #foreach ( $i in $webCsv ) { $i | Add-Member -MemberType NoteProperty -Name 'Source' -Value 'Web Scan' }

            # EXPORT WEB DATA TO EXCEL
            $webCsv | Select-Object -Property $alProperties | Export-Excel @excelParams -WorksheetName 'AlertLogicWeb'
        }
        if ( $PSBoundParameters.ContainsKey('AcunetixScan') ) {
            $authCsv = Import-Csv -Path $AcunetixScan
            $authCsv | Select-Object -Property $authWebProps | Export-Excel @excelParams -WorksheetName 'Acunetix'
        }
        if ( $PSBoundParameters.ContainsKey('NessusSystemScan') ) {
            $nSysCsv = Import-Csv -Path $NessusSystemScan
            $nSysCsv | Export-Excel @excelParams -WorksheetName 'NessusSystem'
        }
        if ( $PSBoundParameters.ContainsKey('NessusWebScan') ) {
            $nWebCsv = Import-Csv -Path $NessusWebScan
            $nWebCsv | Export-Excel @excelParams -WorksheetName 'NessusWeb'
        }
        if ( $PSBoundParameters.ContainsKey('DatabaseScan') ) {
            $DatabaseScan = (Resolve-Path -Path $DatabaseScan).Path
            $dbScan = Import-Excel -Path $DatabaseScan -WorksheetName 'DBScan'
            $dbScan | Export-Excel @excelParams -WorksheetName 'MSSQL'
        }
    }
}
