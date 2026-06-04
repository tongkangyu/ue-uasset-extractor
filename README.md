# ue-uasset-extractor

一个用于 opencode 的 Unreal Engine 资产读取 skill。它可以在不打开 UE 编辑器的情况下，把 `.uasset` / `.umap` 蓝图资产转换为 UAssetAPI JSON，方便继续分析蓝图节点、RPC 标记、函数调用、复制变量和其他底层资产信息。

本项目基于 [@atenfyr](https://github.com/atenfyr) 的 [UAssetGUI](https://github.com/atenfyr/UAssetGUI) 开发，核心资产解析和 JSON 转换能力来自 UAssetGUI。感谢 @atenfyr 和 UAssetGUI 项目提供的优秀工具。

## 功能

- 使用内置 `tools/UAssetGUI.exe` 将 UE4/UE5 `.uasset` / `.umap` 转为 JSON。
- 通过 `SKILL.md` 注册为 opencode skill，遇到 Unreal 资产读取、提取、分析任务时自动触发。
- 提供 `scripts/Export-UAssetJson.ps1` 辅助脚本，优先直接转换源文件。
- 当 `UE4Editor.exe` 或 `UnrealEditor.exe` 锁定源文件导致直接转换失败时，自动复制资产副本后再转换。
- 复制回退时会一起复制同名 `.uexp` 和 `.ubulk` sidecar 文件。
- 默认要求把生成的 JSON 放到 skill 目录之外，避免污染仓库。

## 目录结构

```text
.
|-- SKILL.md                         # opencode skill 触发说明和工作流
|-- scripts/
|   `-- Export-UAssetJson.ps1         # UAssetGUI 转换辅助脚本
|-- tools/
|   `-- UAssetGUI.exe                 # 内置 UAssetGUI 命令行工具
|-- install.ps1                       # 一键安装脚本
|-- README.md
|-- LICENSE
|-- .gitattributes
`-- .gitignore
```

## 环境要求

- Windows PowerShell 5.1 或更新版本。
- opencode 能扫描到本目录所在的 skills 路径。
- Unreal Engine 源项目资产，或兼容的 cooked 资产。
- cooked / unversioned 资产可能需要额外 `.usmap` mappings。

`tools/UAssetGUI.exe` 来自 [UAssetGUI](https://github.com/atenfyr/UAssetGUI)，是运行时依赖，所以仓库会保留这个可执行文件，不应该放进 `.gitignore`。

## 安装

### 一行安装

PowerShell 运行：

```powershell
irm https://raw.githubusercontent.com/tongkangyu/ue-uasset-extractor/main/install.ps1 | iex
```

这个命令会把 skill 安装到 opencode 的全局 skills 目录：

```text
%USERPROFILE%\.config\opencode\skills\ue-uasset-extractor
```

如果目标目录已经是 git 仓库，安装脚本会执行 `git pull --ff-only` 更新。若目标目录已存在但不是 git 仓库，脚本会停止并提示你手动处理，避免覆盖本地文件。

### 使用 git clone 安装

全局安装：

```powershell
git clone https://github.com/tongkangyu/ue-uasset-extractor.git "$env:USERPROFILE\.config\opencode\skills\ue-uasset-extractor"
```

项目级安装：

```text
<your-project>\.opencode\skills\ue-uasset-extractor
```

在项目根目录运行：

```powershell
git clone https://github.com/tongkangyu/ue-uasset-extractor.git ".opencode\skills\ue-uasset-extractor"
```

添加或修改 skill 后，需要重启 opencode。opencode 启动时加载 skill，运行中的会话不会热重载这些文件。

## 使用方法

PowerShell 示例：

```powershell
& "$env:USERPROFILE\.config\opencode\skills\ue-uasset-extractor\scripts\Export-UAssetJson.ps1" `
  -SourceAsset "C:\path\to\Content\All\FppShooter.uasset" `
  -OutputJson "$env:USERPROFILE\.local\share\opencode\uasset-json\my-project\FppShooter.json" `
  -EngineVersion 27
```

带 `.usmap` mappings 的示例：

```powershell
& "$env:USERPROFILE\.config\opencode\skills\ue-uasset-extractor\scripts\Export-UAssetJson.ps1" `
  -SourceAsset "C:\path\to\Asset.uasset" `
  -OutputJson "C:\path\to\Asset.json" `
  -EngineVersion 27 `
  -Mappings "C:\path\to\Mappings.usmap"
```

## 脚本参数

| 参数 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `SourceAsset` | 是 | 无 | 源 `.uasset` 或 `.umap` 文件。 |
| `OutputJson` | 是 | 无 | 输出 JSON 路径，父目录会自动创建。 |
| `EngineVersion` | 否 | `27` | 传给 UAssetGUI 的引擎版本。UE 4.27 可用 `27` 或 `4.27`。 |
| `Mappings` | 否 | 空 | 可选 `.usmap` mappings 文件。 |
| `WorkDir` | 否 | `%TEMP%\opencode\uasset-extract` | 复制回退时使用的临时目录。 |

## 工作流程

1. 检查 `tools/UAssetGUI.exe` 是否存在。
2. 检查 `SourceAsset` 是否存在。
3. 如果 `OutputJson` 已存在，先删除旧输出。
4. 调用 `UAssetGUI.exe tojson` 直接转换源资产。
5. 如果没有生成 JSON，则复制源资产和同名 `.uexp` / `.ubulk` 到临时目录。
6. 对复制出来的资产再次调用 `UAssetGUI.exe tojson`。
7. 成功后输出 `direct` 或 `copy-fallback`，用于判断使用了哪种模式。

## 推荐输出位置

生成的 JSON 建议放到可持久保存但不属于本仓库的位置：

```text
%USERPROFILE%\.local\share\opencode\uasset-json\<project-name>
```

复制回退产生的临时资产建议放到：

```text
%LOCALAPPDATA%\Temp\opencode\uasset-extract
```

除非是在专门添加测试 fixture，否则不要把生成的 JSON 或复制出来的 Unreal 资产放进这个 skill 仓库。

## 常用搜索

JSON 通常比较大，建议先用 `rg` 搜索再精读片段。

查网络 RPC、Multicast 和函数标记：

```powershell
rg -n "Server_|server-|Multicast_|all-|FUNC_NetServer|FUNC_NetMulticast|FunctionFlags" output.json
```

查常见蓝图节点：

```powershell
rg -n "K2Node_CustomEvent|K2Node_CallFunction|K2Node_VariableSet|K2Node_VariableGet" output.json
```

查蓝图字节码调用流：

```powershell
rg -n "EX_VirtualFunction|EX_LocalVirtualFunction|EX_LocalFinalFunction|VirtualFunctionName" output.json
```

按项目里的玩法字段继续缩小范围：

```powershell
rg -n "Health|Ammo|CurrentWeapon|CreatedWeapon|KillNum|KilledNum|RemainingTime|bGameOver" output.json
```

## Git 说明

当前仓库已经是一个独立 git 仓库，初始分支是 `main`。目前没有配置 remote，适合本地 opencode skill 使用。

建议跟踪的内容：

- `SKILL.md`
- `scripts/Export-UAssetJson.ps1`
- `tools/UAssetGUI.exe`
- `install.ps1`
- `README.md`
- `LICENSE`
- `.gitattributes`
- `.gitignore`

不建议跟踪的内容已经写入 `.gitignore`：

- 导出的 `.json` / `.jsonl` 资产 dump。
- 临时复制的 `.uasset` / `.umap` / `.uexp` / `.ubulk`。
- 本地项目 mappings，例如 `.usmap`。
- 日志、PowerShell transcript、编辑器配置和系统文件。
- 临时目录，例如 `tmp/`、`temp/`、`cache/`、`out/`、`dist/`。

提交前建议检查：

```powershell
git status --short
git diff
git log --oneline -5
```

文档、脚本和 git 文件可以这样提交：

```powershell
git add README.md SKILL.md install.ps1 .gitignore
git commit -m "Add install instructions"
```

远程仓库地址：

```powershell
git remote add origin https://github.com/tongkangyu/ue-uasset-extractor.git
git push -u origin main
```

## 限制

- UAssetAPI JSON 是底层序列化结构，不是完整、干净的蓝图图表导出。
- 部分蓝图连线和语义可能需要结合多个字段推断。
- cooked / unversioned 资产可能必须提供 `.usmap` mappings。
- 大型蓝图资产会生成很大的 JSON，建议先搜索再读取。
- 本工具只做提取和分析辅助，不会修改源 `.uasset` 文件。

## 致谢

本项目基于 [@atenfyr](https://github.com/atenfyr) 的 [UAssetGUI](https://github.com/atenfyr/UAssetGUI) 开发。UAssetGUI 提供了 Unreal Engine 资产读取、解析和 `tojson` 转换能力，本 skill 主要是在它的基础上补充 opencode 触发说明、PowerShell 自动化封装、锁文件复制回退和分析工作流。感谢 @atenfyr 和 UAssetGUI 项目。

## License

MIT. See [LICENSE](LICENSE).
