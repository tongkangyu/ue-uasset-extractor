---
name: ue-uasset-extractor
description: Use when reading, extracting, or analyzing Unreal Engine .uasset/.umap Blueprint assets without opening UE Editor. Converts UE4/UE5 assets to UAssetAPI JSON with UAssetGUI and falls back to copy-based extraction when UE4Editor/UnrealEditor locks source files.
---

# UE UAsset Extractor

Use this skill when the user asks to read, inspect, batch extract, convert, or analyze Unreal Engine `.uasset` or `.umap` files, especially Blueprint assets that are binary and cannot be read directly.

Bundled tool:

```text
tools/UAssetGUI.exe
```

Bundled helper:

```text
scripts/Export-UAssetJson.ps1
```

## What This Skill Does

This skill converts Unreal Engine assets to UAssetAPI JSON using UAssetGUI CLI:

```powershell
UAssetGUI.exe tojson <source.uasset|source.umap> <destination.json> <engine-version> [mappings]
```

Use `27` or `4.27` for UE 4.27 assets.

The JSON can expose useful low-level Blueprint information, including:

- `NameMap`
- `Exports`
- `FunctionFlags`
- `FUNC_NetServer`
- `FUNC_NetMulticast`
- `K2Node_CustomEvent`
- `K2Node_CallFunction`
- `K2Node_VariableGet`
- `K2Node_VariableSet`
- Kismet bytecode expressions such as `EX_VirtualFunction`

This is enough for network-architecture inspection such as finding Server RPCs, Multicast events, function calls, replicated-property metadata, and obvious variable reads/writes.

## Important Limits

Do not overclaim. UAssetAPI JSON is a low-level serialized asset representation, not a clean UE Blueprint graph export.

- Some graph wiring may be difficult to reconstruct.
- Some data may appear in `Extras` blobs.
- JSON can be large; use `rg` first, then read targeted windows.
- Cooked/unversioned assets may need `.usmap` mappings.
- For source-project uncooked assets, mappings are usually not needed.

## Default Workflow

1. Identify the asset and engine version.
2. Prefer source-project assets under `Content`, not packaged/cooked files.
3. Run the helper script instead of calling UAssetGUI directly.
4. If Unreal Editor is not locking the file, the helper writes JSON directly from the source asset.
5. If direct conversion fails because the file is locked, the helper copies the asset and sidecar files to a temp folder, then converts the copy.
6. Search the output JSON with `rg` before reading it.
7. Analyze only copied/generated JSON; never modify the original `.uasset` unless explicitly asked.

## Helper Usage

From PowerShell:

```powershell
& "$env:USERPROFILE\.config\opencode\skills\ue-uasset-extractor\scripts\Export-UAssetJson.ps1" `
  -SourceAsset "C:\path\to\Content\All\FppShooter.uasset" `
  -OutputJson "C:\Users\19370\.local\share\opencode\uasset-json\project10\FppShooter.json" `
  -EngineVersion 27
```

Optional mappings:

```powershell
& "$env:USERPROFILE\.config\opencode\skills\ue-uasset-extractor\scripts\Export-UAssetJson.ps1" `
  -SourceAsset "C:\path\to\Asset.uasset" `
  -OutputJson "C:\path\to\Asset.json" `
  -EngineVersion 27 `
  -Mappings "C:\path\to\Mappings.usmap"
```

## Recommended JSON Search Patterns

For network refactor work:

```powershell
rg -n "Server_|server-|Multicast_|all-|FUNC_NetServer|FUNC_NetMulticast|FunctionFlags" output.json
rg -n "K2Node_CustomEvent|K2Node_CallFunction|K2Node_VariableSet|K2Node_VariableGet" output.json
rg -n "Health|Ammo|CurrentWeapon|CreatedWeapon|KillNum|KilledNum|RemainingTime|bGameOver" output.json
```

For Blueprint bytecode call flow:

```powershell
rg -n "EX_VirtualFunction|EX_LocalVirtualFunction|EX_LocalFinalFunction|VirtualFunctionName" output.json
```

## Cleanliness Rules

- Keep generated JSON outside the skill directory unless the user explicitly asks otherwise.
- Prefer `C:\Users\19370\AppData\Local\Temp\opencode\uasset-extract` for temporary copied assets.
- Prefer `C:\Users\19370\.local\share\opencode\uasset-json` for generated JSON that should survive cleanup. Create a project subfolder such as `project10` for each UE project.
- Use `C:\Users\19370\Desktop\cache` only when the user explicitly asks for that temporary desktop cache. Do not treat it as durable storage.
- Do not leave temporary asset copies in project directories.
- Do not modify source `.uasset` files during analysis.

## Known Good Trial

This workflow was validated on:

```text
C:\personal\UE_Project\project10\Content\All\FppShooter.uasset
```

The original file was locked by `UE4Editor.exe`, so the helper-style copy fallback was required. Conversion produced readable JSON containing `K2Node_CustomEvent`, `K2Node_CallFunction`, `FUNC_NetServer`, `FUNC_NetMulticast`, `server-onShootButtonDown`, and `all-onShootButtonDown`.
