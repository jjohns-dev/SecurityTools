function Get-ADUserStatus {
    <#
    .SYNOPSIS
        Get user status
    .DESCRIPTION
        Get user status information including password and logon details
    .PARAMETER Identity
        AD User Identity
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Get-ADUserStatus -Identity jsmith
        Gets the status information for user jsmith
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'AD User Identity')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Identity
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        Import-Module -Name ActiveDirectory -ErrorAction Stop
    }
    Process {
        $props = @(
            'CN'
            'EmailAddress'
            'Created'
            'Enabled'
            'LastLogonDate'
            'DaysSinceLastLogon'
            'LockedOut'
            'AccountLockoutTime'
            'PasswordExpired'
            'ExpiryDate'
            'LastBadPasswordAttempt'
            'BadLogonCount'
            'Modified'
            'PasswordLastSet'
        )

        Get-ADUser -Identity $Identity -Properties "*", "msDS-UserPasswordExpiryTimeComputed" | Select-Object -Property $props
    }
}
