# 接入外部 AI Agent(Claude Code / Cursor / Cline / Codex CLI...)

AI Console 插件在 Godot 编辑器内启动一个 **MCP 服务器**(WebSocket,仅监听 `127.0.0.1:9080-9099`)。
任何支持 MCP 的 AI agent 都通过 `bridge/`(stdio↔WebSocket 桥)连接它,然后就能直接操作编辑器:建节点、搭场景、写脚本、运行游戏、读报错。

前提:**先在 Godot 编辑器里打开一个装了 AI Console 插件的项目**(插件启用后自动启动 MCP 服务器,底部 AI 面板会显示端口)。插件按项目生效:安装版自带的 `MyFirstAIProject` 已预装;其他项目用开始菜单的 **"Add AI Console to a Project"** 一键注入(或把 `project/addons/ai_console` 拷进项目 `addons/` 并在项目设置里启用)。

## Claude Code

```bash
cd bridge && npm install   # 首次一次即可
claude mcp add godot -- node /绝对路径/bridge/src/index.mjs --project /绝对路径/project
```

然后在任意终端:

```bash
claude "在当前场景里建一个 2D 角色,加上摄像机,然后运行看看有没有报错"
```

安装版(Windows 安装包)中桥位于 `C:\Program Files\GodotAI\bridge`:

```bash
claude mcp add godot -- node "C:\Program Files\GodotAI\bridge\src\index.mjs" --project "%USERPROFILE%\Documents\GodotAI\MyFirstAIProject"
```

## Cursor / Cline / 其他 MCP 客户端

在客户端的 MCP 配置(如 `.cursor/mcp.json` 或 Cline 的 MCP 设置)中加入:

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/绝对路径/bridge/src/index.mjs", "--project", "/绝对路径/project"]
    }
  }
}
```

## 连接方式说明

- `--project <dir>`:连接打开了该项目的编辑器(读取 `<dir>/.godot/ai_console_port.json`)。
- `--port <n>`:显式指定端口。
- 都不传:自动发现最近启动的编辑器(全局注册表:Godot 配置目录下 `ai_console_ports/`)。
- 编辑器没开时,请求会排队 15 秒后返回明确错误;桥会持续重连,编辑器一打开即恢复。

## 验证

```bash
npx @modelcontextprotocol/inspector node bridge/src/index.mjs --project /绝对路径/project
```

Inspector 中应能看到 `initialize` 成功、`tools/list` 返回 40+ 工具;或运行脚本化冒烟测试:

```bash
pip install websockets
python clients/smoke_test.py --suite full
```

## 安全

- 服务器只绑定 `127.0.0.1`,不接受外部网络连接。
- 破坏性操作(删文件、覆盖脚本、删子树、改项目设置)默认需要在编辑器内点 Allow 批准(60 秒超时自动拒绝);面板上的 Auto-approve 可跳过。
- 所有场景修改都可用 Ctrl+Z 撤销;组合命令(如 build_character_2d)一次撤销整体回退。
