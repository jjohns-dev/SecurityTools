#Requires -Modules ImportExcel
function Export-NPMAudit {
    <#
    .SYNOPSIS
        Export vulnerability report
    .DESCRIPTION
        Export vulnerability report from provided NPM Audit JSON report
    .PARAMETER Path
        Path to NPM Audit report file in JSON format
    .PARAMETER OutputDirectory
        Path to output directory
    .INPUTS
        System.String.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Export-NPMAudit -Path C:\temp\npmaudit.json
        Exports the NPM audit results from the provided JSON file to an Excel workbook on the desktop.
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Path to NPM Audit file in JSON format')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include "*.json" })]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Path to output directory')]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [System.String] $OutputDirectory = (Join-Path -Path $HOME -ChildPath 'Desktop')
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # GET CONTENT FROM NPM AUDIT FILE
        $json = Get-Content -Path $Path | ConvertFrom-Json

        # SET EXCEL PARAMETERS
        $excelParams = @{
            TableStyle = 'Medium2'
            Style      = (New-ExcelStyle -Bold -Range '1:1' -HorizontalAlignment Center)
            Path       = Join-Path -Path $OutputDirectory -ChildPath ('NPM-Audit_{0:yyyy-MM-dd}.xlsx' -f (Get-Date))
        }

        # SET ARRAYS FOR DATA
        $actions = @()
        $advList = @()

        # GET ADVISORY NUMBERS
        $advisories = $json.advisories | Get-Member -MemberType NoteProperty

        # POPULATE ACTIONS ARRAY
        foreach ($act in $json.actions) {
            $actions += [PSCustomObject] @{
                Action   = $act.action
                Module   = $act.module
                Depth    = $act.depth
                IsMajor  = $act.isMajor
                Resolves = $act.resolves.id -join ', '
            }
        }

        # POPULATE ADVISORY LIST
        foreach ($adv in $advisories) {
            # GET ADVISORY
            $advCont = $json.advisories.($adv.Name)

            # GET CVSS INFO FROM NVD BY CVE NUMBER
            $cvss = Get-CVSSv3BaseScore -CVE $advCont.cves[0]

            foreach ($fin in $advCont.findings) {

                $advList += [PSCustomObject] @{
                    Number             = $adv.Name
                    Version            = $fin.version
                    Paths              = $fin.paths -join '; '
                    Title              = $advCont.title
                    VulnerableVersions = $advCont.vulnerable_versions
                    ModuleName         = $advCont.module_name
                    CVES               = $advCont.cves -join ', '
                    Severity           = $cvss.Severity
                    Score              = $cvss.Score
                    NPMSeverity        = $advCont.severity
                    CWE                = $advCont.cwe
                    PatchedVersions    = $advCont.patched_versions
                    Updated            = $advCont.updated
                    Recommendation     = $advCont.recommendation
                    References         = $advCont.references
                    Overview           = $advCont.overview
                    URL                = $advCont.url
                }
            }

            # REMOVE VARIABLE TO PREVENT REUSE WHEN LOOKUP FAILS
            Remove-Variable -Name 'cvss'
        }

        # GET STATISTICS
        $stats = @(
            [PSCustomObject] @{ Severity = 'Info'; NVDCount = 0; NPMCount = $json.metadata.vulnerabilities.info }
            [PSCustomObject] @{ Severity = 'Low'; NVDCount = $advList.Where({ $_.Severity -eq 'LOW' }).Count; NPMCount = $json.metadata.vulnerabilities.low }
            [PSCustomObject] @{ Severity = 'Medium'; NVDCount = $advList.Where({ $_.Severity -eq 'MEDIUM' }).Count; NPMCount = $json.metadata.vulnerabilities.moderate }
            [PSCustomObject] @{ Severity = 'High'; NVDCount = $advList.Where({ $_.Severity -eq 'HIGH' }).Count; NPMCount = $json.metadata.vulnerabilities.high }
            [PSCustomObject] @{ Severity = 'Critical'; NVDCount = $advList.Where({ $_.Severity -eq 'CRITICAL' }).Count; NPMCount = $json.metadata.vulnerabilities.critical }
        )

        # EXPORT REPORT DATA TO EXCEL
        $stats | Export-Excel @excelParams -WorksheetName Info
        $actions | Export-Excel @excelParams -WorksheetName Actions
        $advList | Export-Excel @excelParams -WorksheetName Advisories
    }
}
