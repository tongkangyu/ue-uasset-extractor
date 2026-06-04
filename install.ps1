param(
    [string]$Target = "$env:USERPROFILE\.config\opencode\skills\ue-uasset-extractor",
    [string]$RepoUrl = "https://github.com/tongkangyu/ue-uasset-extractor.git"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists -Name "git")) {
    throw "git is required but was not found in PATH. Install git first, then run this installer again."
}

$parent = Split-Path -Parent $Target
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

if (Test-Path -LiteralPath $Target) {
    $gitDir = Join-Path $Target ".git"
    if (-not (Test-Path -LiteralPath $gitDir)) {
        throw "Target already exists and is not a git repository: $Target"
    }

    git -C $Target pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update existing installation: $Target"
    }

    "Updated ue-uasset-extractor at $Target"
    "Restart opencode to load the latest skill files."
} else {
    git clone $RepoUrl $Target
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone $RepoUrl to $Target"
    }

    "Installed ue-uasset-extractor to $Target"
    "Restart opencode to load the skill."
}
