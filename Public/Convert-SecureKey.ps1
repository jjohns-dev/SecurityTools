function Convert-SecureKey {
    <#
    .SYNOPSIS
        Convert string to PSCredential object or store as CliXML
    .DESCRIPTION
        This simple function will either create a PSCredential object and store it
        as XML or retrieve a PSCredential object from a Clixml file.
    .PARAMETER Path
        Path to CliXML file containing Credential object
    .PARAMETER Username
        Username
    .PARAMETER SecurePassword
        Password in SecureString type format
    .PARAMETER DestinationPath
        Path to directory for new credential file
    .PARAMETER PassThru
        Return new credential object
    .PARAMETER Force
        Overwrite existing file
    .INPUTS
        None.
    .OUTPUTS
        System.PSCredential.
    .EXAMPLE
        -- EXAMPLE 1 --
        PS C:\> Convert-SecureKey -Username 'Password' -DestinationPath "$HOME\Documents\Creds.xml"
    .EXAMPLE
        -- EXAMPLE 2 --
        PS C:\> Convert-SecureKey -Path C:\Store\Credentials.xml
    .NOTES
        Status: Stable
        It appears that the Clixml file is locked to the user and computer where
        it was created. It cannot be accessed by another user or computer. The
        article below has more information based on a different Cmdlet.
        https://www.randomizedharmony.com/blog/2018/11/25/using-credentials-in-production-scripts
    #>
    [CmdletBinding(DefaultParameterSetName = '_retrieve')]
    Param(
        [Parameter(Mandatory, ParameterSetName = '_retrieve', HelpMessage = 'Path to secure Clixml file')]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf -Filter "*.xml" })]
        [System.String] $Path,

        [Parameter(Mandatory, ParameterSetName = '_create', HelpMessage = 'Username')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Username,

        [Parameter(ParameterSetName = '_create', HelpMessage = 'Enter SecureString')]
        [ValidateNotNullOrEmpty()]
        [SecureString] $SecurePassword,

        [Parameter(Mandatory, ParameterSetName = '_create', HelpMessage = 'Path to new credential XML file')]
        [ValidateScript({ Test-Path -Path ([System.IO.Path]::GetDirectoryName($_)) })]
        [ValidateScript({ [System.IO.Path]::GetExtension($_) -eq '.xml' })]
        [System.String] $DestinationPath,

        [Parameter(ParameterSetName = '_create', HelpMessage = 'Return new credential object')]
        [System.Management.Automation.SwitchParameter] $PassThru,

        [Parameter(ParameterSetName = '_create', HelpMessage = 'Overwrite existing file')]
        [System.Management.Automation.SwitchParameter] $Force
    )

    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        if ( $PSCmdlet.ParameterSetName -eq '_create' ) {

            if ( (Test-Path -Path $DestinationPath -PathType Leaf) -and !$Force ) {
                Write-Error -Message 'File already exists. Use "-Force" to overwrite.' -ErrorAction Stop
            }

            if ( -not $PSBoundParameters.ContainsKey('SecurePassword') ) {
                do {
                    $SecurePassword = Read-Host -Prompt 'Enter password' -AsSecureString
                    $confirmPassword = Read-Host -Prompt 'Confirm password' -AsSecureString

                    $sP = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
                    $cP = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))

                    if ( $sp -cne $cp ) { Write-Warning 'Passwords do not match.' }
                }
                while ( $sp -cne $cp )
            }

            $credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

            $credential | Export-Clixml -Path $DestinationPath

            if ( $PSBoundParameters.ContainsKey('PassThru') ) { $credential }
        }
        else {
            # SQUEEZE VARIABLE
            ($credential = Import-Clixml -Path $Path)
        }
    }
}
