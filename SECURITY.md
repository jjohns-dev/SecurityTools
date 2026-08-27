# Security Policy

## Reporting a Vulnerability

Please do **not** open a public GitHub issue for security vulnerabilities. Report them privately via the [GitHub Security Advisory](../../security/advisories/new) feature for this repository. Include a description, reproduction steps, and impact assessment. You will receive a response within 5 business days.

---

## Known False Positives

### AWS GuardDuty — `Generic.PWSH.Downloader.D` on `ConvertFrom-GZipString.ps1`

**Affected file:** `Public/ConvertFrom-GZipString.ps1`
**Signature:** `Generic.PWSH.Downloader.D.5493857F`

**Why it fires:** The function decompresses a Base64-encoded GZip string using the .NET stream API. The call sequence — `[System.Convert]::FromBase64String()` → `MemoryStream` → `GZipStream(Decompress)` → `StreamReader.ReadToEnd()` — is functionally identical to the "decode and execute" pattern used by PowerShell dropper malware, so heuristic scanners flag it regardless of whether execution follows.

**Assessment:** This is a false positive. The function does not execute its output. It is a pure decompression utility; the output is a string returned to the caller. No network I/O, no `Invoke-Expression`, no reflection-based execution occurs.

**Recommended action for consumers:** Submit the file or release artifact as a false positive to your scanning vendor, referencing this note and the published source at `https://github.com/johnsarie27/SecurityTools`.
