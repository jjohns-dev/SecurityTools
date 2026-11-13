function Find-ServerPendingReboot {
    <#
    .SYNOPSIS
        Check if a server is pending reboot
    .DESCRIPTION
        Check if a server is pending reboot
    .PARAMETER ComputerName
        Gets the server reboot status on the specified computer.
    .INPUTS
        System.String.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Find-ServerPendingReboot -ComputerName 'Server01', 'Server02'
        Returns the pending reboot status for the specified remote computers.
    .NOTES
        Status: Stable
        Adapted from a TechNet Gallery script (gallery since retired; original author and license not recorded)
        https://gallery.technet.microsoft.com/scriptcenter/How-to-check-if-any-4b1e53f2
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, HelpMessage = 'Computer name')]
        [ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
        [Alias('CN')]
        [System.String[]] $ComputerName = $env:COMPUTERNAME
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not $IsWindows) { Write-Error -Message 'Find-ServerPendingReboot requires Windows.' -ErrorAction Stop }

        # THE REGISTRY KEYS BELOW CONTAIN VALUES THAT DETERMINE WHETHER A SYSTEM REQUIRES A REBOOT
        $pendFileKeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\'
        $autoUpdateKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'
        $CBSKeyPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\'

        $sbRemote = @{
            PendingFile = { Get-ItemProperty -Path $Using:pendFileKeyPath -Name PendingFileRenameOperations -ErrorAction SilentlyContinue }
            AutoUpdate  = { Test-Path -Path ('{0}\RebootRequired' -f $Using:autoUpdateKeyPath) }
            CBS         = { Test-Path -Path ('{0}\RebootPending' -f $Using:CBSKeyPath) }
        }

        # SYSTEMS GOVERNED BY SCCM 2012 CONTAIN ADDITIONAL VALUES TO KEEP TRACK OF REQUIRED REBOOT
        $cimParams = @{
            Namespace   = 'Root\ccm\clientSDK'
            ClassName   = 'CCM_ClientUtilities'
            Name        = 'DetermineIfRebootPending'
            ErrorAction = 'SilentlyContinue'
        }
    }

    Process {
        foreach ($cn in $ComputerName) {
            # SET INITIAL VALUE FOR REBOOT VARIABLES
            $pendingFile = $false
            $autoUpdate = $false
            $cbs = $false
            $sccmPending = $false

            # DETERMINE IF TARGET SYSTEM IS LOCAL OR REMOTE
            if ( $cn -eq $env:COMPUTERNAME ) {
                # REMOVE 'USING' KEYWORD AND CONVERT BACK INTO SCRIPT BLOCK
                $sbLocal = @{ }
                foreach ( $k in $sbRemote.Keys ) {
                    $string = $sbRemote[$k] -replace 'Using:', ''
                    $sbLocal[$k] = [System.Management.Automation.ScriptBlock]::Create($String)
                }

                $key = Invoke-Command -ScriptBlock $sbLocal['PendingFile']
                $autoUpdate = Invoke-Command -ScriptBlock $sbLocal['AutoUpdate'] -ErrorAction SilentlyContinue
                $cbs = Invoke-Command -ScriptBlock $sbLocal['CBS']
            }
            else {
                $s = New-PSSession -ComputerName $cn
                $key = Invoke-Command -Session $s -ScriptBlock $sbRemote['PendingFile']
                # THIS RETURNS A BOOLEAN OBJECT WITH ADDITIONAL PROPERTIES (PSComputerName, RunspaceId, etc.)
                # HOWEVER, THOSE PROPERTIES ARE NOT DISPLAYED WITH CALLING THE VARIABLE DIRECTLY
                $autoUpdate = Invoke-Command -Session $s -ScriptBlock $sbRemote['AutoUpdate'] -ErrorAction SilentlyContinue
                $cbs = Invoke-Command -Session $s -ScriptBlock $sbRemote['CBS']

                # CLOSE SESSION
                Remove-PSSession -Session $s
                $cimParams['ComputerName'] = $cn
            }
            if ($key.PendingFileRenameOperations) { $pendingFile = $true }

            $SCCMReboot = Invoke-CimMethod @cimParams
            if ( $cimParams.ContainsKey('ComputerName') ) { $cimParams.Remove('ComputerName') }
            if ( $SCCMReboot.RebootPending -or $SCCMReboot.IsHardRebootPending ) { $sccmPending = $true }

            # CREATE NEW HASH TABLE FOR RESULTS
            $new = @{ ComputerName = $cn ; RebootIsPending = $false }
            if ( $pendingFile -or $autoUpdate -or $cbs -or $sccmPending ) { $new.RebootIsPending = $true }

            # CONVERT HASH TABLE TO OBJECT AND RETURN
            [PSCustomObject] $new
        }
    }
}
