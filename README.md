# SecurityTools

[![validate](https://github.com/jjohns-dev/SecurityTools/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/jjohns-dev/SecurityTools/actions/workflows/validate.yml)
[![release](https://github.com/jjohns-dev/SecurityTools/actions/workflows/release.yml/badge.svg)](https://github.com/jjohns-dev/SecurityTools/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![GitHub release](https://img.shields.io/github/v/release/jjohns-dev/SecurityTools)](https://github.com/jjohns-dev/SecurityTools/releases/latest)

## Description

A PowerShell module for information security, digital forensics, and reporting. Functions span vulnerability triage (CVSSv3, EPSS, CISA KEV), OSINT and network reconnaissance (IP/domain registration, GreyNoise, LAN scanning), system enumeration (software inventory, Windows events, Active Directory), and data export (scan reports, Veracode, SQL VA). Most functions target Windows but cross-platform support is included where possible.

## Requirements

- PowerShell 7.0 or later (tested on Windows and Linux)
- [`ImportExcel`](https://www.powershellgallery.com/packages/ImportExcel) (required — used by the `Export-*` reporting functions)
- Optional, Windows-only: `SqlServer`, `ActiveDirectory`, `GroupPolicy` (loaded on demand by specific functions)

## Installation

Clone the repository and import the module directly:

```powershell
git clone https://github.com/jjohns-dev/SecurityTools.git
Import-Module ./SecurityTools/SecurityTools.psd1
```

## Example Usage

The following demonstrates a basic vulnerability triage workflow using CVE-2021-44228 (Log4Shell):

```powershell
$cve = 'CVE-2021-44228'

# Check whether a CVE appears in CISA's Known Exploited Vulnerabilities catalog
$kev = Get-KEVList
$kev.vulnerabilities.where({ $_.cveID -eq $cve })

# Look up its CVSS v3 base score
Get-CVSSv3BaseScore -CVE $cve

# CVE             Score  Severity
# ---             -----  --------
# CVE-2021-44228  10.0   Critical

# Get the EPSS probability-of-exploitation score
(Get-EPSS -CVE $cve).data

# cve            : CVE-2021-44228
# epss           : 0.97573
# percentile     : 0.99974
# date           : 2026-06-11
```

## Latest Version Notes

See the [Releases](https://github.com/jjohns-dev/SecurityTools/releases) page
for version notes. Release notes are auto-generated from merged pull requests
and categorized via [.github/release.yml](.github/release.yml).

## Disclaimer

Feel free to create issues or pull requests; however, this project is developed
for use by a specific team of engineers, not for broad use.

## Repo Layout

- [Public](./Public) — functions that are available when using the module
- [Private](./Private) — functions/tools that are used internally by the module
- [Tests](./Tests) — Pester tests
- [Build](./Build) — tools to handle automated testing/builds

## Contributions, Feature Requests, and Feedback

To start, please read the [contribution guide](CONTRIBUTING.md).

- Read the current content and help fix any spelling mistakes or grammatical errors.
- Choose an existing [issue](https://github.com/jjohns-dev/SecurityTools/issues) and submit a pull request to fix it.
- Open a new issue to report an opportunity for improvement.
