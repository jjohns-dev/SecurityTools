#Requires -Modules ImportExcel
function Export-WebScan {
    <#
    .SYNOPSIS
        Export vulnerability report
    .DESCRIPTION
        Export vulnerability report from provided Acunetix XML report
    .PARAMETER Path
        Path to Acunetix report file in XML format
    .PARAMETER OutputDirectory
        Path to output directory
    .INPUTS
        System.String.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Export-WebScan -Path C:\myReport.xml
        Processes the Acunetix XML report and produces an Excel Spreadsheet of the results
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to Acunetix report file in XML format')]
        [ValidateScript( { Test-Path -Path $_ -PathType Leaf -Include "*.xml" })]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Path to output directory')]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [System.String] $OutputDirectory = (Join-Path -Path $HOME -ChildPath 'Desktop')
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        function Get-Severity {
            <# =====================================================================
            .SYNOPSIS
                Get severity
            .DESCRIPTION
                Get severity rating from CVSS v3 score
            .PARAMETER Score
                CVSS v3 Score
            .INPUTS
                System.ValueType.Double.
            .OUTPUTS
                System.String.
            .EXAMPLE
                PS C:\> <example usage>
                Explanation of what the example does
            .NOTES
                https://nvd.nist.gov/vuln-metrics/cvss
            ===================================================================== #>
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory, HelpMessage = 'CVSS v3 Score')]
                [ValidateNotNullOrEmpty()]
                [System.Double] $Score
            )

            $severity = switch ( $Score ) {
                { $_ -eq 0.0 } { 'None' }
                { $_ -ge 0.1 -and $_ -le 3.9 } { 'Low' }
                { $_ -ge 4.0 -and $_ -le 6.9 } { 'Medium' }
                { $_ -ge 7.0 -and $_ -le 8.9 } { 'High' }
                { $_ -ge 9.0 } { 'Critical' }
                default { 'Unknown' }
            }

            $severity
        }

        [System.Xml.XmlDocument] $xml = Get-Content -Path $Path
        $report = [System.Collections.Generic.List[System.Object]]::new()

        $excelParams = @{
            FreezeTopRow = $true
            MoveToEnd    = $true
            BoldTopRow   = $true
            AutoFilter   = $true
            Style        = (New-ExcelStyle -Bold -Range '1:1' -HorizontalAlignment Center)
            Path         = Join-Path -Path $OutputDirectory -ChildPath ('WebScans_{0:yyyy-MM-dd}.xlsx' -f (Get-Date))
        }

        $propOrder = @(
            'Name'
            'Description'
            'Type'
            'Impact'
            'Affects'
            'CVSS'
            'Severity'
            'CVSS3'
            'CVSS3Severity'
            'CWE'
            'CVE'
            'ModuleName'
            'Details'
            'Parameter'
            'DetailedInfo'
            'Recommendation'
            'Request'
            'Status'
        )
    }

    Process {
        foreach ( $item in $xml.ScanGroup.Scan.ReportItems.ReportItem ) {
            $new = @{
                Name           = $item.Name.'#cdata-section'
                ModuleName     = $item.ModuleName.'#cdata-section'
                Details        = $item.Details.'#cdata-section'
                Affects        = $item.Affects.'#cdata-section'
                Parameter      = $item.Parameter.'#cdata-section'
                Status         = $item.IsFalsePositive.'#cdata-section'
                Severity       = $item.Severity.'#cdata-section'
                Type           = $item.Type.'#cdata-section'
                Impact         = $item.Impact.'#cdata-section'
                Description    = $item.Description.'#cdata-section'
                DetailedInfo   = $item.DetailedInformation.'#cdata-section'
                Recommendation = $item.Recommendation.'#cdata-section'
                Request        = $item.TechnicalDetails.Request.'#cdata-section' # THERE MAY BE MORE THAN 1 REQUEST
                CWE            = $item.CWEList.CWE.'#cdata-section' # THERE MAY BE MORE THAN 1
                CVE            = $item.CWEList.CVE.'#cdata-section' # THERE MAY BE MORE THAN 1
                CVSS           = $item.CVSS.Score.'#cdata-section'
                CVSS3          = $item.CVSS3.Score.'#cdata-section'
                CVSS3Severity  = 'Unknown'
            }

            if ( $new['CVSS3'] ) { $new['CVSS3Severity'] = Get-Severity -Score ([System.Double] $new['CVSS3']) }

            $report.Add([PSCustomObject] $new)
        }

        # RETURN
        $report | Select-Object -Property $propOrder | Export-Excel @excelParams
    }
}
