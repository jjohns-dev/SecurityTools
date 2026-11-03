function Get-LoggedOnUser {
    <#
    .SYNOPSIS
        Show all users currently logged onto system
    .DESCRIPTION
        This function gets all user sessions on a remote system.
    .PARAMETER ComputerName
        Hostname or IP address of target system to find users.
    .INPUTS
        System.String.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> Get-LoggedOnUser -ComputerName 'Server01'
        Returns all active user sessions on Server01.
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(HelpMessage = 'Target computer name')]
        [ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
        [Alias('CN')]
        [System.String] $ComputerName
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # SET SELF REFERENCE
        $self = @('localhost', '127.0.0.1', $env:COMPUTERNAME, '::1')
    }
    Process {
        # CHECK FOR COMPUTERNAME PARAMETER
        if ($PSBoundParameters.ContainsKey('ComputerName') -and $ComputerName -notin $self) {
            # OPEN REMOTE SESSION
            $session = New-PSSession -ComputerName $ComputerName

            # GET TEXT UTILITY
            $hasModule = Get-Module -ListAvailable -Name 'Microsoft.PowerShell.TextUtility' -PSSession $session

            # EXECUTE REMOTELY
            if ($hasModule) { Invoke-Command -Session $session -ScriptBlock { query user | ConvertFrom-TextTable } }
            else { Invoke-Command -Session $session -ScriptBlock { query user } }
        }
        else {
            # GET TEXT UTILITY
            $hasModule = Get-Module -ListAvailable -Name 'Microsoft.PowerShell.TextUtility'

            # EXECUTE LOCALLY
            if ($hasModule) { Invoke-Command -ScriptBlock { query user | ConvertFrom-TextTable } }
            else { Invoke-Command -ScriptBlock { query user } }
        }
    }
}
