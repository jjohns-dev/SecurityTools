[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Synthetic credential used only to build a PSCredential fixture in-memory for this test file; not a real secret.')]
param()

BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'Convert-SecureKey' -Fixture {

    BeforeAll {
        $script:SecurePW = ConvertTo-SecureString -String 'SuperPassword123' -AsPlainText -Force
    }

    Context -Name "'_create' parameter set" -Fixture {
        BeforeEach {
            $script:DestPath = Join-Path -Path $TestDrive -ChildPath ('cred-{0}.xml' -f ([System.Guid]::NewGuid().ToString('N')))
        }

        It -Name 'creates an XML file at -DestinationPath' -Test {
            Convert-SecureKey -DestinationPath $script:DestPath -Username 'user' -SecurePassword $script:SecurePW
            Test-Path -Path $script:DestPath -PathType Leaf | Should -BeTrue
        }

        It -Name 'serializes a PSCredential object that round-trips back' -Test {
            Convert-SecureKey -DestinationPath $script:DestPath -Username 'alice' -SecurePassword $script:SecurePW
            $cred = Import-Clixml -Path $script:DestPath
            $cred | Should -BeOfType [System.Management.Automation.PSCredential]
            $cred.UserName | Should -Be 'alice'
        }

        It -Name 'returns the PSCredential when -PassThru is supplied' -Test {
            $cred = Convert-SecureKey -DestinationPath $script:DestPath -Username 'bob' -SecurePassword $script:SecurePW -PassThru
            $cred | Should -BeOfType [System.Management.Automation.PSCredential]
            $cred.UserName | Should -Be 'bob'
        }

        It -Name 'returns nothing when -PassThru is omitted' -Test {
            $result = Convert-SecureKey -DestinationPath $script:DestPath -Username 'silent' -SecurePassword $script:SecurePW
            $result | Should -BeNullOrEmpty
        }

        It -Name 'refuses to overwrite an existing file without -Force' -Test {
            Convert-SecureKey -DestinationPath $script:DestPath -Username 'first' -SecurePassword $script:SecurePW
            { Convert-SecureKey -DestinationPath $script:DestPath -Username 'second' -SecurePassword $script:SecurePW -ErrorAction Stop } |
                Should -Throw -ExpectedMessage '*already exists*'
        }

        It -Name 'overwrites an existing file when -Force is supplied' -Test {
            Convert-SecureKey -DestinationPath $script:DestPath -Username 'first' -SecurePassword $script:SecurePW
            Convert-SecureKey -DestinationPath $script:DestPath -Username 'second' -SecurePassword $script:SecurePW -Force
            (Import-Clixml -Path $script:DestPath).UserName | Should -Be 'second'
        }
    }

    Context -Name "'_create' parameter validation" -Fixture {
        It -Name 'rejects a -DestinationPath with a non-.xml extension' -Test {
            $bad = Join-Path -Path $TestDrive -ChildPath 'creds.txt'
            { Convert-SecureKey -DestinationPath $bad -Username 'user' -SecurePassword $script:SecurePW } |
                Should -Throw
        }

        It -Name 'rejects a -DestinationPath whose parent directory does not exist' -Test {
            $bad = Join-Path -Path $TestDrive -ChildPath 'no-such-dir/creds.xml'
            { Convert-SecureKey -DestinationPath $bad -Username 'user' -SecurePassword $script:SecurePW } |
                Should -Throw
        }

        It -Name 'rejects an empty -Username' -Test {
            $dest = Join-Path -Path $TestDrive -ChildPath 'empty-user.xml'
            { Convert-SecureKey -DestinationPath $dest -Username '' -SecurePassword $script:SecurePW } |
                Should -Throw
        }
    }

    Context -Name "'_retrieve' parameter set" -Fixture {
        BeforeAll {
            $script:RetrievePath = Join-Path -Path $TestDrive -ChildPath 'retrieve.xml'
            Convert-SecureKey -DestinationPath $script:RetrievePath -Username 'retriever' -SecurePassword $script:SecurePW
        }

        It -Name 'returns a PSCredential object for a valid file' -Test {
            $cred = Convert-SecureKey -Path $script:RetrievePath
            $cred | Should -BeOfType [System.Management.Automation.PSCredential]
            $cred.UserName | Should -Be 'retriever'
        }
    }

    Context -Name "'_retrieve' parameter validation" -Fixture {
        It -Name 'rejects a -Path that does not exist' -Test {
            $missing = Join-Path -Path $TestDrive -ChildPath 'no-such.xml'
            { Convert-SecureKey -Path $missing } | Should -Throw
        }

        It -Name 'rejects a -Path that is not an .xml file' -Test {
            $nonXml = Join-Path -Path $TestDrive -ChildPath 'creds.txt'
            Set-Content -Path $nonXml -Value 'not xml'
            { Convert-SecureKey -Path $nonXml } | Should -Throw
        }
    }

    Context -Name 'parameter set conflict' -Fixture {
        It -Name 'rejects supplying both -Path and -Username/-DestinationPath' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'conflict.xml'
            Convert-SecureKey -DestinationPath $src -Username 'u' -SecurePassword $script:SecurePW
            $dest = Join-Path -Path $TestDrive -ChildPath 'conflict2.xml'
            { Convert-SecureKey -Path $src -Username 'u' -SecurePassword $script:SecurePW -DestinationPath $dest } |
                Should -Throw
        }
    }
}
