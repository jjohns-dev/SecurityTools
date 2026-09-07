[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingComputerNameHardcoded',
    '',
    Justification = 'Placeholder hostnames used to assert UNC path formatting; not real infrastructure names.')]
param()

BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'Get-UncPath' -Fixture {

    Context -Name 'Windows-style UNC (default)' -Fixture {
        It -Name 'builds a UNC path with backslashes and the dollar-sign drive' -Test {
            Get-UncPath -Path 'C:\Temp\Share' -ComputerName 'MyServer' |
                Should -Be '\\MyServer\C$\Temp\Share'
        }

        It -Name 'preserves nested directories' -Test {
            Get-UncPath -Path 'D:\a\b\c\file.txt' -ComputerName 'host1' |
                Should -Be '\\host1\D$\a\b\c\file.txt'
        }
    }

    Context -Name 'Unix-style UNC' -Fixture {
        It -Name 'builds a Unix-style UNC path with forward slashes' -Test {
            Get-UncPath -Path 'C:\Temp\Share' -ComputerName 'MyServer' -Unix |
                Should -Be '//MyServer/C$/Temp/Share'
        }
    }

    Context -Name 'ComputerName aliases' -Fixture {
        It -Name 'accepts -HostName as an alias for -ComputerName' -Test {
            Get-UncPath -Path 'C:\x' -HostName 'host2' | Should -Be '\\host2\C$\x'
        }

        It -Name 'accepts -CN as an alias for -ComputerName' -Test {
            Get-UncPath -Path 'C:\x' -CN 'host3' | Should -Be '\\host3\C$\x'
        }

        It -Name 'accepts -Target as an alias for -ComputerName' -Test {
            Get-UncPath -Path 'C:\x' -Target 'host4' | Should -Be '\\host4\C$\x'
        }
    }

    Context -Name 'pipeline input' -Fixture {
        It -Name 'accepts a path from the pipeline' -Test {
            ('E:\share\file.log' | Get-UncPath -ComputerName 'srv') |
                Should -Be '\\srv\E$\share\file.log'
        }
    }

    Context -Name 'parameter validation' -Fixture {
        It -Name 'rejects a path without a drive letter' -Test {
            { Get-UncPath -Path '/etc/passwd' -ComputerName 'srv' } | Should -Throw
        }

        It -Name 'rejects an empty path' -Test {
            { Get-UncPath -Path '' -ComputerName 'srv' } | Should -Throw
        }

        It -Name 'rejects a bare drive letter (must include subpath)' -Test {
            { Get-UncPath -Path 'C:\' -ComputerName 'srv' } | Should -Throw
        }
    }
}
