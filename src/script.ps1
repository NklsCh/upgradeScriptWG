param (
    [string[]]$IgnoreApps = @()  # Optional parameter to pass in IDs to skip
)

# Set console encoding to UTF8 to support german umlauts
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

class Software {
    [string]$Id
    [string]$Version
    [string]$AvailableVersion
    [bool]$SkipBool
    [string]$Skip
}

class Upgrade {
    [string]$Id
    [string]$Status
    [string]$PreviousVersion
    [string]$NewVersion
}

Add-Content "ids.txt" $IgnoreApps | Select-Object -Unique

$toSkip = @()
if (Test-Path "ids.txt") {
    $toSkip = Get-Content "ids.txt"
}

$toSkip += $IgnoreApps | Select-Object -Unique

# Ask user if no skip IDs were provided
if ($toSkip.Length -le 0) {
    Write-Host "You are not skipping any software upgrades. Do you want to skip some? (y/n)"
    $answer = Read-Host
    if ($answer -eq "y") {
        Write-Host "Please enter the IDs of the software you want to skip, separated by a comma."
        $answer = Read-Host
        $toSkip += $answer.Split(',')
        Add-Content "ids.txt" $toSkip
    }
    else {
        Add-Content "ids.txt" ""
    }
}

$upgradeResult = winget upgrade | Out-String
$lines = $upgradeResult.Split([Environment]::NewLine)

# Find the line that starts with Name (headers)
$fl = 0
while (-not $lines[$fl].StartsWith("Name")) {
    $fl++
}

# Determine header positions (German/English)
if ($lines[$fl].StartsWith("Name") -and $lines[$fl].Contains("Quelle")) {
    # German headers
    $idStart = $lines[$fl].IndexOf("ID")
    $versionStart = $lines[$fl].IndexOf("Version")
    $availableStart = $lines[$fl].IndexOf("Verfügbar")
    $sourceStart = $lines[$fl].IndexOf("Quelle")
}
else {
    # English headers
    $idStart = $lines[$fl].IndexOf("Id")
    $versionStart = $lines[$fl].IndexOf("Version")
    $availableStart = $lines[$fl].IndexOf("Available")
    $sourceStart = $lines[$fl].IndexOf("Source")
}

# Check for missing headers
$missingHeaders = @()
if ($idStart -eq -1) { $missingHeaders += "Id" }
if ($versionStart -eq -1) { $missingHeaders += "Version" }
if ($availableStart -eq -1) { $missingHeaders += "Available" }
if ($sourceStart -eq -1) { $missingHeaders += "Source" }

if ($missingHeaders) {
    foreach ($header in $missingHeaders) { Write-Host "$header not found" }
    exit
}

# Create a list of software to upgrade
$upgradeList = @()
for ($i = $fl + 1; $i -le $lines.Length; $i++) {
    if ($lines[$i].Contains("Aktualisierungen") -or $lines[$i].Contains("upgrades available")) { break }
    $line = $lines[$i]
    if ($line.Length -gt ($availableStart + 1) -and -not $line.StartsWith('-') -or $line.StartsWith('Name')) {
        $id = $line.Substring($idStart, $versionStart - $idStart).TrimEnd()
        $version = $line.Substring($versionStart, $availableStart - $versionStart).TrimEnd()
        $available = $line.Substring($availableStart, $sourceStart - $availableStart).TrimEnd()
        $software = [Software]::new()
        $software.Id = $id
        $software.Version = $version
        $software.AvailableVersion = $available
        if ($toSkip -contains $software.Id) {
            $software.Skip = "[✓]"
            $software.SkipBool = $true
        }
        else {
            $software.Skip = "[ ]"
            $software.SkipBool = $false
        }
        $upgradeList += $software
    }
}

$upgradeList | Format-Table -Property Id, Version, AvailableVersion, Skip

Write-Host "Found $($upgradeList.Count) software to upgrade | Skip $(($upgradeList | Where-Object { $_.SkipBool }).Count)"

foreach ($package in $upgradeList) {
    if ($package.SkipBool -eq $false) {
        Start-Job -ScriptBlock { winget upgrade $args[0] } -Name $package.Id -ArgumentList $package.Id | Out-Null
    }
}

# Ensure you are running PowerShell 7 or later
$packagesToUpgrade = $upgradeList | Where-Object { -not $_.SkipBool }

# Run upgrades in parallel
$packagesToUpgrade | ForEach-Object -Parallel {
    winget upgrade --id $_.Id | Out-Null
} -ThrottleLimit 10  # Adjust ThrottleLimit as needed for your system

# Output results (optional)
$packagesToUpgrade | Format-Table -Property Id, Version, AvailableVersion


Clear-Host
$upgrades | Format-Table
