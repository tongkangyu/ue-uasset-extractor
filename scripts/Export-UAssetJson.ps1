param(
    [Parameter(Mandatory = $true)]
    [string]$SourceAsset,

    [Parameter(Mandatory = $true)]
    [string]$OutputJson,

    [string]$EngineVersion = "27",

    [string]$Mappings = "",

    [string]$WorkDir = "$env:TEMP\opencode\uasset-extract"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillDir = Split-Path -Parent $scriptDir
$toolPath = Join-Path $skillDir "tools\UAssetGUI.exe"

function Invoke-UAssetToJson {
    param(
        [string]$Tool,
        [string]$Source,
        [string]$Destination,
        [string]$Version,
        [string]$MapFile
    )

    $args = @("tojson", $Source, $Destination, $Version)
    if (-not [string]::IsNullOrWhiteSpace($MapFile)) {
        $args += $MapFile
    }

    $process = Start-Process -FilePath $Tool -ArgumentList $args -Wait -PassThru
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Exists = Test-Path -LiteralPath $Destination
    }
}

function Copy-AssetFamily {
    param(
        [string]$Source,
        [string]$DestinationDirectory
    )

    New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null

    $sourceItem = Get-Item -LiteralPath $Source
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceItem.Name)
    $sourceDir = $sourceItem.DirectoryName
    $copiedMain = Join-Path $DestinationDirectory $sourceItem.Name

    Copy-Item -LiteralPath $Source -Destination $copiedMain -Force

    foreach ($extension in @(".uexp", ".ubulk")) {
        $sidecar = Join-Path $sourceDir ($baseName + $extension)
        if (Test-Path -LiteralPath $sidecar) {
            Copy-Item -LiteralPath $sidecar -Destination (Join-Path $DestinationDirectory ($baseName + $extension)) -Force
        }
    }

    return $copiedMain
}

if (-not (Test-Path -LiteralPath $toolPath)) {
    throw "UAssetGUI.exe not found at $toolPath"
}

if (-not (Test-Path -LiteralPath $SourceAsset)) {
    throw "Source asset not found: $SourceAsset"
}

$outputDir = Split-Path -Parent $OutputJson
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

if (Test-Path -LiteralPath $OutputJson) {
    Remove-Item -LiteralPath $OutputJson -Force
}

$direct = Invoke-UAssetToJson -Tool $toolPath -Source $SourceAsset -Destination $OutputJson -Version $EngineVersion -MapFile $Mappings
if ($direct.Exists) {
    Get-Item -LiteralPath $OutputJson | Select-Object @{Name="Mode";Expression={"direct"}}, FullName, Length
    exit 0
}

$assetName = [System.IO.Path]::GetFileNameWithoutExtension($SourceAsset)
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$copyDir = Join-Path $WorkDir ("$assetName-$stamp")
$copiedAsset = Copy-AssetFamily -Source $SourceAsset -DestinationDirectory $copyDir

$copyResult = Invoke-UAssetToJson -Tool $toolPath -Source $copiedAsset -Destination $OutputJson -Version $EngineVersion -MapFile $Mappings
if ($copyResult.Exists) {
    Get-Item -LiteralPath $OutputJson | Select-Object @{Name="Mode";Expression={"copy-fallback"}}, FullName, Length
    exit 0
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    $clipboardError = [System.Windows.Forms.Clipboard]::GetText()
} catch {
    $clipboardError = ""
}

throw "UAssetGUI did not create JSON. Source=$SourceAsset Output=$OutputJson DirectExit=$($direct.ExitCode) CopyExit=$($copyResult.ExitCode) ClipboardError=$clipboardError"
