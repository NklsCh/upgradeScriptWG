# Set console encoding to UTF8 to support german umlauts
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

class Software {
    [string]$Name
    [string]$Id
    [string]$Version
    [string]$AvailableVersion
}

$upgradeResult = winget upgrade | Out-String

$lines = $upgradeResult.Split([Environment]::NewLine)

# Find the line that starts with Name, it contains the table headers
$fl = 0
while (-not $lines[$fl].StartsWith("Name")) {
    $fl++
}

# Check if german language is used
if ($lines[$fl].StartsWith("Name") -and $lines[$fl].Contains("Quelle")) {
    # Use german headers
    $idStart = $lines[$fl].IndexOf("ID")
    $versionStart = $lines[$fl].IndexOf("Version")
    $availableStart = $lines[$fl].IndexOf("Verfügbar")
    $sourceStart = $lines[$fl].IndexOf("Quelle")
}
else {
    # Use english headers
    $idStart = $lines[$fl].IndexOf("Id")
    $versionStart = $lines[$fl].IndexOf("Version")
    $availableStart = $lines[$fl].IndexOf("Available")
    $sourceStart = $lines[$fl].IndexOf("Source")
}

# Check if all headers are found
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
For ($i = $fl + 1; $i -le $lines.Length; $i++) {
    if ($lines[$i].Contains("Aktualisierungen") -or $lines[$i].Contains("upgrades available")) { break }
    $line = $lines[$i]
    if ($line.Length -gt ($availableStart + 1) -and -not $line.StartsWith('-') -or $line.StartsWith('Name')) {
        $name = $line.Substring(0, $idStart).TrimEnd()
        $id = $line.Substring($idStart, $versionStart - $idStart).TrimEnd()
        $version = $line.Substring($versionStart, $availableStart - $versionStart).TrimEnd()
        $available = $line.Substring($availableStart, $sourceStart - $availableStart).TrimEnd()
        $software = [Software]::new()
        $software.Name = $name
        $software.Id = $id
        $software.Version = $version
        $software.AvailableVersion = $available

        $upgradeList += $software
    }
}

$upgradeList | Format-Table

Write-Host "Found $($upgradeList.Count) software to upgrade"

$toSkip = @(
    'PackageIDTo.Exclude',
    '...'
)

foreach ($package in $upgradeList) {
    if (-not ($toSkip -contains $package.Id)) {
        Write-Host "Going to upgrade package $($package.id)"
        Start-Job -ScriptBlock { winget upgrade $args[0] } -Name $package.id -ArgumentList $package.id | Out-Null
        # & winget upgrade $package.id
    }
    else {    
        Write-Host "Skipped upgrade to package $($package.id)"
    }
}

# Wait for all jobs to finish and get the results
$jobs = Invoke-Command -ScriptBlock { Get-Job }
Wait-Job -Job $jobs | Out-Null
foreach ($job in $jobs) {
    if ($job.State -eq 'Completed') {
        Write-Host "Upgrade of $($job.Name) completed"
    }
    else {
        Write-Host "Upgrade of $($job.Name) failed"
    }
    $job | Remove-Job
}