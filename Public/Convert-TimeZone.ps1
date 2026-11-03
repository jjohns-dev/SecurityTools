function Convert-TimeZone {
    <#
    .SYNOPSIS
        Convert US time zones
    .DESCRIPTION
        Convert US and UTC time zones
    .PARAMETER Time
        Time to convert
    .PARAMETER SourceTimeZone
        Time zone of Time parameter (defaults to local)
    .PARAMETER TargetTimeZone
        Time zone of desired conversion (default is UTC)
    .INPUTS
        System.String[].
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Convert-TimeZone -Time "2019-06-01 10:00 PM" -Source UTC -Target Eastern
        Convert "2019-06-01 10:00 PM" from UTC to Eastern time zone.
    .NOTES
        Status: Stable
        [DateTime]::UtcNow
        $DateTimeObject.ToLocalTime()
        $DateTimeObject.ToUniversalTime()
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    Param(
        [Parameter(ValueFromPipeline, HelpMessage = 'Time to convert')] #Mandatory,
        [ValidateScript({ [System.DateTime]::Parse($_) })]
        [System.String[]] $Time = (Get-Date),

        [Parameter(HelpMessage = 'Source time zone (default is local)')]
        #[ValidateScript({ (Get-TimeZone -ListAvailable | Where-Object DisplayName -Match '\(US').Id })]
        [ValidateSet('Local', 'UTC', 'Pacific', 'Mountain', 'Central', 'Eastern', 'GMT')]
        [Alias('Source')]
        [System.String] $SourceTimeZone = 'Local',

        [Parameter(HelpMessage = 'Target time zone (default is UTC)')]
        #[ValidateScript({ (Get-TimeZone -ListAvailable | Where-Object DisplayName -Match '\(US').Id })]
        [ValidateSet('Local', 'UTC', 'Pacific', 'Mountain', 'Central', 'Eastern', 'GMT')]
        [Alias('Target')]
        [System.String] $TargetTimeZone = 'UTC'
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # FIND OS
        if ( $PSVersionTable.PSVersion.Major -lt 6 ) { $Windows = $true }

        # FIND TIME ZONE
        if ( $IsWindows -or $Windows ) {
            $TimeZoneHash = @{
                Local    = Get-TimeZone
                UTC      = Get-TimeZone -Id 'UTC'
                Pacific  = Get-TimeZone -Id 'Pacific Standard Time'
                Mountain = Get-TimeZone -Id 'Mountain Standard Time'
                Central  = Get-TimeZone -Id 'Central Standard Time'
                Eastern  = Get-TimeZone -Id 'Eastern Standard Time'
                GMT      = Get-TimeZone -Id 'GMT Standard Time'
            }
        }
        elseif ( $IsMacOS -or $IsLinux ) {
            $TimeZoneHash = @{
                Local    = Get-TimeZone
                UTC      = Get-TimeZone -Id 'UTC'
                Pacific  = Get-TimeZone -Id 'America/Los_Angeles'
                Mountain = Get-TimeZone -Id 'America/Denver'
                Central  = Get-TimeZone -Id 'America/Chicago'
                Eastern  = Get-TimeZone -Id 'America/New_York'
                GMT      = Get-TimeZone -Id 'Europe/London'
            }
        }

        $source = $TimeZoneHash[$SourceTimeZone]
        $target = $TimeZoneHash[$TargetTimeZone]
    }
    Process {
        # LOOP ALL TIME ARGUMENTS
        foreach ( $t in $Time ) {
            # CONVERT ARGUMENTS TO PROPER DATA TYPES
            $oldTime = Get-Date -Date $t

            # SETUP RESULTS HASHTABLE
            $new = @{ $SourceTimeZone = $oldTime }

            # CONVERT SOURCE TO UTC
            $new.UTC = [System.TimeZoneInfo]::ConvertTimeToUtc($oldTime, $source)

            # CONVERT UTC TO TARGET
            $new[$TargetTimeZone] = [System.TimeZoneInfo]::ConvertTime($new.UTC, $target)

            # RETURN RESULT
            [PSCustomObject] $new
        }
    }
}
