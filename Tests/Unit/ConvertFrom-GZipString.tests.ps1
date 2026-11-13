[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    '',
    Justification = 'New-GZipFixture is a test fixture factory that builds an in-memory Base64 string and changes no state; the rule fires on the verb alone.'
)]
Param()

BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'ConvertFrom-GZipString' -Fixture {

    BeforeAll {
        # Build a known Base64-gzipped fixture using the same .NET APIs the function uses.
        function New-GZipFixture {
            param([string] $Text)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
            $ms = [System.IO.MemoryStream]::new()
            $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
            $gz.Write($bytes, 0, $bytes.Length)
            $gz.Dispose()
            [System.Convert]::ToBase64String($ms.ToArray())
        }
    }

    Context -Name 'round-trip' -Fixture {
        It -Name 'decompresses a Base64-gzipped string back to the original' -Test {
            $original = 'The quick brown fox jumps over the lazy dog.'
            $fixture = New-GZipFixture -Text $original
            ConvertFrom-GZipString -String $fixture | Should -Be $original
        }

        It -Name 'preserves multi-line content' -Test {
            $original = "line one`nline two`nline three"
            $fixture = New-GZipFixture -Text $original
            ConvertFrom-GZipString -String $fixture | Should -Be $original
        }

        It -Name 'preserves UTF-8 multi-byte characters' -Test {
            $original = 'café — résumé — 北京'
            $fixture = New-GZipFixture -Text $original
            ConvertFrom-GZipString -String $fixture | Should -Be $original
        }
    }

    Context -Name 'pipeline + array input' -Fixture {
        It -Name 'decompresses each item when an array is piped in' -Test {
            $a = New-GZipFixture -Text 'first'
            $b = New-GZipFixture -Text 'second'
            $result = $a, $b | ConvertFrom-GZipString
            $result | Should -Be @('first', 'second')
        }
    }

    Context -Name 'error cases' -Fixture {
        It -Name 'rejects a non-Base64 string' -Test {
            { ConvertFrom-GZipString -String '!not-base64!' } | Should -Throw
        }
    }
}
