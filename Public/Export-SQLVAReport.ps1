function Export-SQLVAReport {
    <#
    .SYNOPSIS
        This function is used to scan SQL Server DBs for Vulnerabilities
    .DESCRIPTION
        The script relies on the native Vulnerability Assessment scan tool imbedded
        in SQL Server Management Studio 17.0 & up
    .PARAMETER ServerName
        Name of SQL Server
    .PARAMETER BaselinePath
        Path to baseline file in JSON format
    .PARAMETER OutputDirectory
        Path to output directory for new SQL Vulnerability Assessment reports.
        Defaults to the Desktop folder in the user's home directory.
    .PARAMETER PassThru
        Returns path to directory containing new reports
    .INPUTS
        System.String.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Export-SQLVAReport.ps1 -SN MySQLServer -BP C:\Baselines -DP C:\Reports
        This exports a scan report using SQL Vulnerability Assessment tool for the master
        database on MySQLServer using the corresponding baseline file in C:\Baselines.
    .NOTES
        Status: Stable
        https://docs.microsoft.com/en-us/sql/relational-databases/security/sql-vulnerability-assessment?view=sql-server-2017
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'SQL server name')]
        [ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
        [Alias('SN', 'Server')]
        [System.String] $ServerName,

        [Parameter(HelpMessage = 'Path to baseline file in JSON format')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Include *.json })]
        [Alias('BP', 'Baseline')]
        [System.String] $BaselinePath,

        [Parameter(HelpMessage = 'Output directory')]
        [ValidateScript( { Test-Path -Path $_ -PathType Container })]
        [Alias('DestinationPath')]
        [System.String] $OutputDirectory = (Join-Path -Path $HOME -ChildPath 'Desktop'),

        [Parameter(HelpMessage = 'Return path to report directory')]
        [System.Management.Automation.SwitchParameter] $PassThru
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # IMPORT REQUIRED MODULES
        Import-Module -Name SqlServer -ErrorAction Stop

        # GET DATE OBJECTS AND SET OUTPUT FOLDER
        $date = Get-Date
        $dateFolder = '{0}\{1}' -f $date.ToString("yyyy"), $date.ToString("MM")
        $folder = Join-Path -Path $OutputDirectory -ChildPath $dateFolder

        # CREATE FOLDER IF NOT EXIST
        if ( -not (Test-Path -Path $folder) ) {
            try { New-Item -Path $folder -ItemType Directory | Out-Null }
            catch { Write-Error ('Could not create folder path: [{0}]' -f $folder) }
        }

        # CREATE SPLATTER TABLE
        $SVAParams = @{
            DatabaseName   = "master"
            ServerInstance = $ServerName
        }
    }

    Process {
        # CREATE FILE
        $ReportFile = '{0:yyyy-MM-dd}_{1}.xlsx' -f (Get-Date), $ServerName

        # CHECK FOR BASELINE PARAM
        if ( $PSBoundParameters.ContainsKey('BaselinePath') ) {
            try {
                $SVAParams['Baseline'] = Import-SqlVulnerabilityAssessmentBaselineSet -FolderPath $BaselinePath
            }
            catch {
                Write-Warning ('Failed to generate baseline for [{0}] using file [{1}]' -f $ServerName, $BaselinePath)
            }
        }

        # EXECUTE SCAN AND SET TO VARIABLE
        $Scan = Invoke-SqlVulnerabilityAssessmentScan @SVAParams

        # EXPORT SCAN RESULT TO EXCEL SPREADSHEET
        $Scan | Export-SqlVulnerabilityAssessmentScan -FolderPath (Join-Path -Path $folder -ChildPath $ReportFile)
    }

    End {
        # RETURN PATH TO REPORT FOLDER
        if ( $PSBoundParameters.ContainsKey('PassThru') ) { Write-Output -InputObject $folder }
    }
}
