function Get-SamlBrowserPath {
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(HelpMessage = 'Override the installed Microsoft Edge executable path')]
        [System.String] $BrowserPath
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $candidates = @(
            if ($BrowserPath) {
                $BrowserPath
            }
            elseif ($IsWindows) {
                $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
                if (Test-Path -LiteralPath $registryPath) {
                    (Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop).'(default)'
                }
                if (${env:ProgramFiles(x86)}) {
                    Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft/Edge/Application/msedge.exe'
                }
            }
            elseif ($IsMacOS) {
                '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'
            }
            else {
                (Get-Command -Name 'microsoft-edge' -CommandType Application -ErrorAction SilentlyContinue |
                    Select-Object -First 1).Source
            }
        )
        foreach ($candidate in $candidates) {
            if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                (Get-Item -LiteralPath $candidate -ErrorAction Stop).FullName
                return
            }
        }
        Write-Error -Message 'Microsoft Edge not found. Install Edge or specify its executable with -BrowserPath.' -ErrorAction Stop
    }
}
