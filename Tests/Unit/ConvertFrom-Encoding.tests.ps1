BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'ConvertFrom-Encoding' -Fixture {

    Context -Name 'Base64 decode (default)' -Fixture {
        It -Name "decodes 'SGVsbG8sIFdvcmxkIQ==' to 'Hello, World!'" -Test {
            ConvertFrom-Encoding -String 'SGVsbG8sIFdvcmxkIQ==' | Should -Be 'Hello, World!'
        }

        It -Name 'round-trips with ConvertTo-Encoding' -Test {
            $plain = 'The quick brown fox jumps over the lazy dog.'
            $encoded = ConvertTo-Encoding -String $plain
            ConvertFrom-Encoding -String $encoded | Should -Be $plain
        }

        It -Name 'decodes UTF-8 byte sequences (multi-byte characters)' -Test {
            # 'café' is 5 bytes in UTF-8 -> 'Y2Fmw6k='
            ConvertFrom-Encoding -String 'Y2Fmw6k=' | Should -Be 'café'
        }

        It -Name 'rejects a non-Base64 string' -Test {
            { ConvertFrom-Encoding -String '!not-base64!' } | Should -Throw
        }
    }

    Context -Name 'URL decode' -Fixture {
        It -Name "decodes percent-escapes back to 'https://google.com/?q=hello world'" -Test {
            ConvertFrom-Encoding -String 'https%3A%2F%2Fgoogle.com%2F%3Fq%3Dhello%20world' -Encoding URL |
            Should -Be 'https://google.com/?q=hello world'
        }

        It -Name 'round-trips with ConvertTo-Encoding -Encoding URL' -Test {
            $plain = 'a b/c?d=e&f=g'
            $encoded = ConvertTo-Encoding -String $plain -Encoding URL
            ConvertFrom-Encoding -String $encoded -Encoding URL | Should -Be $plain
        }
    }

    Context -Name 'parameter validation' -Fixture {
        It -Name 'rejects an unknown -Encoding value' -Test {
            { ConvertFrom-Encoding -String 'abc' -Encoding 'Rot13' } | Should -Throw
        }
    }
}
