# Godot AI Console

在 Godot 编辑器底部内嵌一个 **AI 聊天控制台**,并内置 **MCP 服务器**——让 AI 直接操作编辑器本身:

> “帮我建一个 2D 角色” → AI 自动创建 CharacterBody2D + 精灵 + 碰撞体 + 摄像机,写好移动脚本、注册输入映射、保存场景;还能运行游戏、读取报错、自己修复。

两条接入通道,同一套能力(约 40 个编辑器命令,统一注册、统一审批、统一可撤销):

| 通道 | 说明 |
|---|---|
| **底部聊天面板** | 编辑器内直接对话。支持 Anthropic(Claude)与任何 OpenAI 兼容 API(OpenAI / DeepSeek / Ollama / LM Studio / OpenRouter...),API Key 在面板 Settings 里配置(存编辑器层,不进版本库)。 |
| **外部 Agent(MCP)** | Claude Code、Cursor、Cline、Codex CLI 等在命令行终端操控编辑器。见 [docs/connecting-agents.md](docs/connecting-agents.md)。 |

**技术路线**:纯 GDScript 的 `EditorPlugin` 插件(不改引擎源码),锁定 **Godot 4.4.x stable**。

## 能力一览

- **场景/节点**:建/删/改/挂/拖动节点、设属性(自动类型转换)、分组、信号连接、场景实例化、保存
- **脚本**:创建/编辑 GDScript(先解析校验,坏代码拒绝落盘)、挂载到节点
- **资源/文件**:读写项目文件、生成占位纹理(无素材也能搭场景)、创建任意 Resource
- **项目**:读写项目设置、注册输入映射、设置主场景
- **运行调试**:运行/停止游戏、捕获运行时报错(closed loop:建→跑→读错→修)、编辑器视口截图
- **组合命令**:`build_character_2d/3d`、`scaffold_level_2d`、`setup_ui_screen` —— 一条命令搭完整结构,一次 Ctrl+Z 整体撤销
- **安全**:所有修改可撤销;破坏性操作需在编辑器内批准;服务器仅监听 localhost

## 快速开始(开发者)

```bash
# 1) 用 Godot 4.4.x 打开 project/ —— 插件自动启用,底部出现 “AI” 面板
# 2) 面板 Settings 填 API Key 即可聊天;或接入 Claude Code:
cd bridge && npm install
claude mcp add godot -- node $PWD/src/index.mjs --project $PWD/../project
claude "查看当前场景,然后帮我搭一个平台跳跃关卡"
```

## 仓库结构

```
project/                Godot 项目(开发环境 = 安装包模板)
  addons/ai_console/    插件本体
    core/               命令注册中心、undo 集成、参数校验、节点解析
    commands/           全部编辑器命令(每命令一文件,自动发现)
    mcp/                WebSocket JSON-RPC + MCP 协议层 + 端口发现文件
    chat/               底部面板 UI、SSE 流式 LLM 客户端、双 Provider、tool-use 循环
    debug/              运行时报错捕获(游戏日志 tail)
  tests/                headless 校验脚本与文档生成器
bridge/                 stdio↔WebSocket 桥(Claude Code 等 MCP 客户端由此接入)
clients/smoke_test.py   对活编辑器的脚本化 MCP 冒烟测试
packaging/              Windows 安装包(Inno Setup + 官方 Godot 校验下载)
scripts/ci_validate.sh  headless CI 门禁
```

## 测试

```bash
# 桥:单元 + 端到端(无需 Godot)
cd bridge && npm test

# Godot 侧:headless 门禁(需要 Godot 4.4 二进制)
GODOT_BIN=/path/to/godot bash scripts/ci_validate.sh

# 对活编辑器的完整冒烟(先在编辑器中打开 project/)
pip install websockets
python clients/smoke_test.py --suite full
```

## 构建 Windows 安装包

GitHub Actions 打 tag(`v*`)自动构建,或本地(Windows,需 Inno Setup 6 与 Node):

```powershell
cd bridge; npm ci; cd ..
./packaging/download_godot.ps1     # 下载官方 Godot 并校验 SHA-512
./packaging/build_installer.ps1    # 产出 packaging/output/GodotAI-Setup-*.exe
```

安装后:开始菜单“Godot AI Console”直接打开预装插件的首个项目;模板复制在 `文档\GodotAI\MyFirstAIProject`。

## 给其他项目添加 AI(导入的旧项目 / 新建的项目)

AI 控制台是**按项目安装的编辑器插件**——只有装了插件的项目才有 AI 面板。给任意项目添加:

1. 开始菜单 → **“Add AI Console to a Project”** → 选择项目文件夹(含 `project.godot` 的那层)
2. 用 Godot AI Console 重新打开该项目,底部即出现 AI 面板

命令行等价操作:`powershell -File "C:\Program Files\GodotAI\tools\add_ai_to_project.ps1" -Project <项目路径>`。重复运行安全(幂等),也可用来升级项目里的旧版插件。

## 为什么有时打开的是旧版 Godot?

新装的 Godot 和你电脑上原有的 Godot **共享同一份项目列表**(`%APPDATA%\Godot`),两边都能看到所有项目。但双击 `project.godot` 文件或用旧快捷方式启动的是旧版 exe。要确保用带 AI 的编辑器:

- 认准开始菜单/桌面的 **“Godot AI Console”** 与 **“Godot (Project Manager)”** 快捷方式
- 或在安装时勾选 **“Open .godot project files with Godot AI”** 文件关联(默认勾选),此后双击 `project.godot` 就会用新版编辑器打开

## 已知限制(v0.1)

- 聊天面板需自备 API Key;外部 Agent 通道(Claude Code 等)不需要
- 脚本解析错误详情在编辑器 Output 面板(校验只返回是否通过)
- API Key 明文存于编辑器配置;可改用 `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` 环境变量
- 安装包未签名,首次运行需通过 Windows SmartScreen 的“仍要运行”
