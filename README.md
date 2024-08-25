# Winget upgrade script

Simple winget upgrade script that excludes certain packages from being upgraded

Inspired by the work of [Codewerks](https://github.com/alkampfergit) and rewritten to have german language support

## Usage

1. Download the script
2. Ensure that you use PowerShell 7
3. Run the script with the following command:
   `.\script.ps1`
   3.5. Add optional parameters to exclude packages from being upgraded:
   `.\script.ps1 -IgnoreApps "Package1", "Package2"`
