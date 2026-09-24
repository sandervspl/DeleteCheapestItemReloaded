Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$fixtureParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $fixtureParent ("dci-deploy-test-" + [Guid]::NewGuid().ToString("N"))
$scriptPath = Join-Path $projectRoot "scripts\copy-to-wow.ps1"

function Assert-True($Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

try {
    $flavors = @{
        "_classic_era_" = "wow_classic_era"
        "_anniversary_" = "wow_anniversary"
        "_classic_" = "wow_classic"
        "_forever_" = "wow_forever"
        "_retail_" = "wow"
        "_classic_beta_" = "wow_classic_beta"
        "_classic_ptr_" = "wow_classic_ptr"
        "_ptr2_" = "wowxptr"
    }
    foreach ($name in $flavors.Keys) {
        $client = Join-Path $fixtureRoot $name
        New-Item -ItemType Directory -Path $client -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $client ".flavor.info") -Value @("Product Flavor!STRING:0", $flavors[$name])
    }

    # BuffTimers also recognizes installs whose launcher metadata is missing.
    $exeClient = Join-Path $fixtureRoot "_exe_only_beta_"
    New-Item -ItemType Directory -Path $exeClient -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $exeClient "WowClassicB.exe") | Out-Null
    $expectedClients = @($flavors.Keys) + @("_exe_only_beta_")

    # Ordinary folders and unfinished installs must not receive addon files.
    foreach ($name in @("_empty_", "Data")) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $name) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $fixtureRoot "Data\.flavor.info") -Value "wow_classic"

    & $scriptPath -WowRoot $fixtureRoot -WhatIf
    foreach ($name in $expectedClients) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot "$name\Interface"))) "WhatIf wrote files to $name"
    }
    $legacy = Join-Path $fixtureRoot "_classic_era_\Interface\AddOns\DeleteCheapestItem"
    New-Item -ItemType Directory -Path $legacy -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacy "user-note.txt") -Value "keep"
    $saved = Join-Path $fixtureRoot "_classic_era_\WTF\Account\test\SavedVariables"
    New-Item -ItemType Directory -Path $saved -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $saved "DeleteCheapestItem.lua") -Value "DCI_DB = { MaxQuality = 0 }"

    & $scriptPath -WowRoot $fixtureRoot
    foreach ($name in $expectedClients) {
        $destination = Join-Path $fixtureRoot "$name\Interface\AddOns\DeleteCheapestItem"
        foreach ($file in @("DeleteCheapestItem.toc", "Localization.lua", "DeleteCheapestItem.lua")) {
            $expected = (Get-FileHash -LiteralPath (Join-Path $projectRoot $file)).Hash
            $actual = (Get-FileHash -LiteralPath (Join-Path $destination $file)).Hash
            Assert-True ($actual -eq $expected) "Deployed $file differs in $name"
        }
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $destination "Tests"))) "Development files were deployed"
    }
    foreach ($name in @("_empty_", "Data")) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot "$name\Interface"))) "Non-client folder $name was deployed"
    }
    Assert-True ((Get-Content -LiteralPath (Join-Path $legacy "user-note.txt")) -eq "keep") "Existing addon files were removed"
    Assert-True ((Get-Content -LiteralPath (Join-Path $saved "DeleteCheapestItem.lua")) -eq "DCI_DB = { MaxQuality = 0 }") "Saved variables were altered"
    & $scriptPath -WowRoot (Join-Path $fixtureRoot "_anniversary_")

    # Verify a direct beta path copies again, rather than only passing discovery.
    $betaLua = Join-Path $fixtureRoot "_classic_beta_\Interface\AddOns\DeleteCheapestItem\DeleteCheapestItem.lua"
    Set-Content -LiteralPath $betaLua -Value "outdated beta installation"
    & $scriptPath -WowRoot (Join-Path $fixtureRoot "_classic_beta_")
    Assert-True ((Get-FileHash -LiteralPath $betaLua).Hash -eq
        (Get-FileHash -LiteralPath (Join-Path $projectRoot "DeleteCheapestItem.lua")).Hash) "Direct beta deployment did not update the addon"

    $rejected = $false
    try { & $scriptPath -WowRoot (Join-Path $fixtureRoot "_empty_") } catch { $rejected = $true }
    Assert-True $rejected "An empty client folder was accepted"
    $rejected = $false
    try { & $scriptPath -WowRoot (Join-Path $fixtureRoot "missing") } catch { $rejected = $true }
    Assert-True $rejected "A missing explicit directory was accepted"
    Write-Host "Deployment tests passed (live/beta/PTR clients, executable detection, direct beta path, WhatIf, file preservation and invalid paths)."
}
finally {
    # Delete only the unique fixture created above, after checking its resolved boundary.
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolved = (Resolve-Path -LiteralPath $fixtureRoot).ProviderPath
        $parent = [IO.Path]::GetDirectoryName($resolved)
        if ($parent.TrimEnd('\', '/') -ne $fixtureParent.TrimEnd('\', '/') -or
            [IO.Path]::GetFileName($resolved) -notmatch '^dci-deploy-test-[a-f0-9]{32}$') {
            throw "Refusing to remove unexpected test fixture: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
