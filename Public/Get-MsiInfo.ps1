function Get-MsiInfo {
    <#
    .SYNOPSIS
        Get MSI information
    .DESCRIPTION
        Get information from MSI file
    .PARAMETER Path
        Path to MSI file
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-MsiInfo -Path "C:\myMsi.msi"
        Returns all available product info for myMsi.msi
    .NOTES
        Status: Stable
        Adapted from a script by Nickolaj Andersen (MSEndpointMgr, 2014)
        https://msendpointmgr.com/2014/08/22/how-to-get-msi-file-information-with-powershell/
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $Path
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        try {
            # READ PROPERTY FROM MSI DATABASE
            if (-Not ([System.IO.Path]::IsPathRooted($Path))) {
                $MsiPath = (Resolve-Path -Path $Path).Path -As [System.IO.FileInfo]
            }
            else {
                $MsiPath = (Get-ChildItem -Path $Path) -As [System.IO.FileInfo]
            }
            if ($MsiPath.Extension -ne ".msi") {
                Write-Error -Message 'Path must be an msi file.' -ErrorAction Stop
            }

            $MsiValue = @{}
            Write-Verbose -Message 'Open and Read property from MSI database'
            $MsiObj = New-Object -ComObject WindowsInstaller.Installer
            $MsiDb = $MsiObj.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $MsiObj, @($MsiPath.FullName, 0))
            $View = $MsiDb.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $MsiDb, ('SELECT * FROM Property'))
            $View.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $View, $null)
            While ($Record = $View.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $View, $null)) {
                $Name = $Record.GetType().InvokeMember('StringData', 'GetProperty', $null, $Record, 1)
                $Value = $Record.GetType().InvokeMember('StringData', 'GetProperty', $null, $Record, 2)
                $MsiValue.Add($Name, $Value)
            }
            $MsiValue.Add('FileName', $MsiPath.Name)
            $MsiValue.Add('FilePath', $MsiPath.FullName)

            Write-Verbose "Commit database and close view"
            $MsiDb.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $MsiDb, $null)
            $View.GetType().InvokeMember('Close', 'InvokeMethod', $null, $View, $null)
            $MsiDb = $null
            $View = $null

            # RETURN THE VALUE
            return ([PSCustomObject] $MsiValue)
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    End {
        # RUN GARBAGE COLLECTION AND RELEASE COMOBJECT
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($MsiObj) | Out-Null
        $MsiObj = $null
        [System.GC]::Collect()
    }
}
