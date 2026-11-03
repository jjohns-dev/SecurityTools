function Get-Software {
    <#
    .SYNOPSIS
        Get all installed software
    .DESCRIPTION
        Get software inventory from Windows Registry
    .PARAMETER Name
        Software name
    .PARAMETER ComputerName
        Remote computer name
    .PARAMETER ExcludeUsers
        Exclude user software registry hive
    .PARAMETER All
        Return all properties for registry keys
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-Software -All
        This returns all properties of the registry keys holding the software inventory
    .NOTES
        Status: Stable
        https://4sysops.com/archives/find-the-product-guid-of-installed-software-with-powershell/
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    Param(
        [Parameter(HelpMessage = "Software name")]
        [ValidateNotNullOrEmpty()]
        [System.String] $Name,

        [Parameter(ValueFromPipeline, HelpMessage = 'Computer name')]
        [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
        [Alias('CN')]
        [System.String] $ComputerName,

        [Parameter(HelpMessage = 'Exclude user software registry hives')]
        [Alias('NoUsers')]
        [System.Management.Automation.SwitchParameter] $ExcludeUsers,

        [Parameter(HelpMessage = 'Return registry objects with all properties')]
        [System.Management.Automation.SwitchParameter] $All
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not $IsWindows) { Write-Error -Message 'Get-Software requires Windows.' -ErrorAction Stop }

        # SET VARS FOR REMOTE CALLS
        if ( $PSBoundParameters.ContainsKey('All') ) { $getAll = $true } else { $getAll = $false }
        if ( $PSBoundParameters.ContainsKey('Name') ) { $getName = $true } else { $getName = $false }
        if ( $PSBoundParameters.ContainsKey('ExcludeUsers') ) { $getUsers = $false } else { $getUsers = $true }

        # CREATE SCRIPTBLOCK
        $scriptBlock = {
            # SET UNINSTALL REGISTRY HIVE PATH
            $uninstallKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            )

            # CHECK THAT CURRENT PRINCIPLE HAS ADMIN PRIVILEGES
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ( $isAdmin ) { Write-Verbose 'Current user has admin privileges' }

            # GET USER KEYS
            if ( $true -eq $Using:getUsers -and $isAdmin ) {
                # ADD NEW PSDRIVE FOR HKEY CURRENT USER HIVE
                New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null

                # ADD USER KEY HIVES
                foreach ( $key in (Get-ChildItem "HKU:") ) {
                    if ( $key.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' ) {
                        $path = 'HKU:\{0}\Software\Microsoft\Windows\CurrentVersion\Uninstall' -f $key.PSChildName
                        if ( Test-Path $path ) {
                            $uninstallKeys += $path
                        }
                    }
                }
            }
            else {
                Write-Warning 'Unable to retrieve User registry keys. Elevated priveleges required.'
            }

            # SET WHERE STATEMENT
            if ( $true -eq $Using:getName ) { $where = { $_.GetValue('DisplayName') -like "*$Using:Name*" } }
            else { $where = { $_.GetValue('DisplayName') } }

            # GET SOFTWARE REGISTRY KEYS
            if ( $true -eq $Using:getAll ) {
                Get-ChildItem -Path $uninstallKeys | Where-Object $where
            }
            else {
                # SET PROPERTIES
                $properties = @(
                    @{N = 'GUID'; E = { $_.PSChildName } },
                    @{N = 'Name'; E = { $_.GetValue('DisplayName') } },
                    @{N = 'Version'; E = { $_.GetValue('DisplayVersion') } },
                    @{N = 'InstallDate'; E = { $_.GetValue('InstallDate') } },
                    @{N = 'InstallLocation'; E = { $_.GetValue('InstallLocation') } },
                    @{N = 'UninstallString'; E = { $_.GetValue('UninstallString') } }
                )

                # GET SPECIFIED PROPERTIES
                Get-ChildItem -Path $uninstallKeys | Where-Object $where | Select-Object -Property $properties
            }
        }

        # SET PARAM HASH
        $splat = @{ ScriptBlock = $scriptBlock }
    }
    Process {
        # CHECK FOR LOCAL SYSTEM OR NO COMPUTERNAME
        if ( !$PSBoundParameters.ContainsKey('ComputerName') -or $ComputerName -eq $env:COMPUTERNAME ) {
            # EXECUTE LOCALLY
            $string = $scriptBlock -replace 'Using:', ''
            $splat['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($string)
        }
        else {
            # ADD COMPUTERNAME IF PROVIDED
            $splat['ComputerName'] = $ComputerName
        }

        # EXECUTE COMMAND
        $software = Invoke-Command @splat

        # RETURN
        if ( $getAll ) { $software }
        else { $software | Sort-Object -Property Name }
    }
}
