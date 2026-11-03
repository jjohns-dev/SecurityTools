function Uninstall-MSI {
    <#
    .SYNOPSIS
        Uninstall existing MSI application
    .DESCRIPTION
        Uninstall existing MSI application
    .PARAMETER ProductId
        Product ID
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Uninstall-MSI -ProductId '109A5A16-E09E-4B82-A784-D1780F1190D6'
        Remove installed package with ID '{109A5A16-E09E-4B82-A784-D1780F1190D6}'
    .NOTES
        Status: Stable
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Product ID')]
        [ValidatePattern('[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}')]
        [System.String] $ProductId
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not $IsWindows) { Write-Error -Message 'Uninstall-MSI requires Windows.' -ErrorAction Stop }

        # SET COMMON KEY PATHS
        $uninstallKey = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )
    }
    Process {
        # CHECK FOR EXISTENCE OF APPLICATION
        $hasApp = Get-ChildItem -Path $uninstallKey | Where-Object Name -Match $ProductId

        if ($hasApp) {
            # SET MSI PARAMETERS
            $msiParams = @{ FilePath = 'MsiExec.exe'; PassThru = $true; Wait = $true; NoNewWindow = $true }
            $removeArgs = '/x {0} /qn' -f $ProductId

            Write-Verbose -Message ('MSI arguments: "{0}"' -f $removeArgs)

            # SHOULD PROCESS
            if ($PSCmdlet.ShouldProcess($hasApp.GetValue('DisplayName'), "Uninstall application")) {
                # UNINSTALL USING START-PROCESS
                Write-Verbose -Message ('Uninstalling product with ID "{0}"' -f $ProductId)
                $uninstall = Start-Process -ArgumentList $removeArgs @msiParams

                # VALIDATE UNINSTALL AND OUTPUT RESULT
                if ($uninstall.ExitCode -EQ 0) { Write-Output -InputObject 'Uninstall completed successfully' }
                else { Write-Error -Message ('Uninstall failed with exit code: "{0}"' -f $uninstall.ExitCode) -ErrorAction Stop }
            }
        }
        else {
            Write-Output -InputObject ('Application with product ID [{0}] not found.' -f $ProductId)
        }
    }
}
