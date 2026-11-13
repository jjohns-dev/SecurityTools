BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'ConvertTo-Encoding' -Fixture {

    Context -Name 'Base64 encode (default)' -Fixture {
        It -Name "encodes 'Hello, World!' to 'SGVsbG8sIFdvcmxkIQ=='" -Test {
            ConvertTo-Encoding -String 'Hello, World!' | Should -Be 'SGVsbG8sIFdvcmxkIQ=='
        }

        It -Name 'encodes UTF-8 multi-byte characters correctly' -Test {
            # 'café' -> 'Y2Fmw6k=' (5 UTF-8 bytes)
            ConvertTo-Encoding -String 'café' | Should -Be 'Y2Fmw6k='
        }

        It -Name 'round-trips through ConvertFrom-Encoding' -Test {
            $plain = 'round-trip me 1234 !@#$%^&*()'
            ConvertFrom-Encoding -String (ConvertTo-Encoding -String $plain) | Should -Be $plain
        }
    }

    Context -Name 'URL encode' -Fixture {
        It -Name "encodes 'https://google.com/' to percent-escapes" -Test {
            ConvertTo-Encoding -String 'https://google.com/' -Encoding URL |
            Should -Be 'https%3A%2F%2Fgoogle.com%2F'
        }

        It -Name 'escapes spaces as %20 (RFC 3986), not as plus signs' -Test {
            ConvertTo-Encoding -String 'a b' -Encoding URL | Should -Be 'a%20b'
        }
    }

    Context -Name 'pipeline input' -Fixture {
        It -Name 'accepts strings from the pipeline' -Test {
            ('test' | ConvertTo-Encoding) | Should -Be 'dGVzdA=='
        }
    }

    Context -Name 'parameter validation' -Fixture {
        It -Name 'rejects an empty string' -Test {
            { ConvertTo-Encoding -String '' } | Should -Throw
        }

        It -Name 'rejects an unknown -Encoding value' -Test {
            { ConvertTo-Encoding -String 'abc' -Encoding 'Rot13' } | Should -Throw
        }
    }
}
