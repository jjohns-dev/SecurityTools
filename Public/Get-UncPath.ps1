function Get-UncPath {
    <#
    .SYNOPSIS
        Generate UNC path from local or relative path
    .DESCRIPTION
        This function accepts a relative path (e.g., C:\Windows\temp) and
        returns the UNC version of the same path.
    .PARAMETER Path
        Local or relative path to be changed into a UNC path. This should
        include the drive letter and full path to the target directory.
    .PARAMETER ComputerName
        Hostname or servername to bind to the UNC path. If not provided then
        localhost will be assumed.
    .PARAMETER Unix
        This is a switch parameter that will return Unix formatted UNC path.
    .INPUTS
        System.String.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Get-UncPath -Path 'C:\Temp\Share'
        Returns the UNC path for C:\Temp\Share on the local machine.
    .EXAMPLE
        PS C:\> Get-UncPath -Path 'D:\Share' -Unix -ComputerName 'MyServer'
        Returns the Unix-formatted UNC path for D:\Share on MyServer.
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Local path')]
        [ValidatePattern("[A-Z]:\\.+")]
        [System.String] $Path,

        [Parameter(HelpMessage = 'Targer server hostname')]
        #[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 2 })]
        [Alias('HostName', 'CN', 'Computer', 'Host', 'Target')]
        [System.String] $ComputerName,

        [Parameter(HelpMessage = 'Use UNUX-style path')]
        [System.Management.Automation.SwitchParameter] $Unix
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        if ( -not $PSBoundParameters.ContainsKey('ComputerName') ) { $ComputerName = ( hostname ) }

        if ( $Path.Substring(0.2) -match '[A-Z]:' ) {
            if ( $Unix ) {
                $unixPath = $Path.Replace('\', '/')
                $UncPath = '//' + $ComputerName + '/' + $unixPath.Replace(':', '$')
            }
            else {
                $UncPath = '\\' + $ComputerName + '\' + $Path.Replace(':', '$')
            }
            $UncPath
        }
        else { Write-Output -InputObject 'Invalid input' }
    }
}
