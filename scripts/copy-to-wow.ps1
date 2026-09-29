[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [Alias("Path")]
    [string[]] $WowRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Keep the original install identity so WoW loads existing per-character DCI_DB settings.
$addonName = "DeleteCheapestItem"
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceFiles = @("DeleteCheapestItem.toc", "Localization.lua", "DeleteCheapestItem.lua", "Media\icon.tga")
foreach ($file in $sourceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $file) -PathType Leaf)) {
        throw "Required addon file is missing: $file"
    }
}

function Test-WowClientDirectory {
    param([System.IO.DirectoryInfo] $Directory)

    # Match BuffTimers: deployment discovers installed clients, including beta/PTR.
    if ($Directory.Name -notmatch '^_.+_$') { return $false }

    $flavorFile = Join-Path $Directory.FullName ".flavor.info"
    if (Test-Path -LiteralPath $flavorFile -PathType Leaf) {
        return $true
    }

    return @(
        Get-ChildItem -LiteralPath $Directory.FullName -Filter "Wow*.exe" -File -ErrorAction SilentlyContinue
    ).Count -gt 0
}

$explicitRoots = $PSBoundParameters.ContainsKey("WowRoot")
$candidateRoots = @()
if ($explicitRoots) {
    if (-not $WowRoot -or $WowRoot.Count -eq 0) { throw "Supply at least one WoW installation or client directory." }
    $candidateRoots = $WowRoot
}
else {
    if (Get-PSDrive -Name HKLM -ErrorAction SilentlyContinue) {
        $uninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        foreach ($entry in Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue) {
            $name = $entry.PSObject.Properties["DisplayName"]
            $location = $entry.PSObject.Properties["InstallLocation"]
            if ($name -and $name.Value -like "World of Warcraft*" -and $location) {
                $candidateRoots += $location.Value
            }
        }
    }
    foreach ($variable in @("ProgramFiles", "ProgramFiles(x86)")) {
        $directory = [Environment]::GetEnvironmentVariable($variable)
        if ($directory) { $candidateRoots += Join-Path $directory "World of Warcraft" }
    }
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        if ($drive.Root) {
            foreach ($path in @("World of Warcraft", "Games\World of Warcraft", "Blizzard Games\World of Warcraft")) {
                $candidateRoots += Join-Path $drive.Root $path
            }
        }
    }
}

$clients = @{}
foreach ($candidate in $candidateRoots) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $expanded = [Environment]::ExpandEnvironmentVariables($candidate.Trim().Trim('"'))
    if (-not (Test-Path -LiteralPath $expanded -PathType Container)) {
        if ($explicitRoots) { throw "WoW directory not found: $expanded" }
        continue
    }
    $root = Get-Item -LiteralPath (Resolve-Path -LiteralPath $expanded).ProviderPath
    $found = $false
    foreach ($directory in @($root) + @(Get-ChildItem -LiteralPath $root.FullName -Directory -Force)) {
        if (Test-WowClientDirectory $directory) {
            $clients[$directory.FullName] = $directory
            $found = $true
        }
    }
    if ($explicitRoots -and -not $found) { throw "No installed WoW client found in: $expanded" }
}

if ($clients.Count -eq 0) { throw "No installed WoW clients found. Pass -WowRoot with an installation or client directory." }

foreach ($client in @($clients.Values | Sort-Object FullName)) {
    $destination = Join-Path $client.FullName "Interface\AddOns\$addonName"
    if ($PSCmdlet.ShouldProcess($destination, "Copy DeleteCheapestItem Reloaded runtime files")) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        foreach ($file in $sourceFiles) {
            $destinationFile = Join-Path $destination $file
            New-Item -ItemType Directory -Path (Split-Path -Parent $destinationFile) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $sourceRoot $file) -Destination $destinationFile -Force
        }
        Write-Host "Copied DeleteCheapestItem Reloaded to $($client.FullName)."
    }
}
