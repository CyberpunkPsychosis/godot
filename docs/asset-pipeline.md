# 素材与动画工作流(软件分工 + 引擎内命令)

原则:**生成/制作在专业软件,获取/组装在引擎里由 AI 自动化**。
不知道从哪学起?先看 [learning-path.md](learning-path.md) —— 完整流程图 + 每个软件的最小学习集。

## 推荐软件栈(自行下载学习)

| 环节 | 软件 | 说明 |
|---|---|---|
| 2D 像素画+逐帧动画 | **Aseprite**(付费,便宜) | 行业标准;搭配 **PixelLab** 插件可 AI 生成精灵/动画帧再手工修 |
| 3D 建模/改模/导出 | **Blender**(免费) | 一切 3D 的枢纽,导出 glTF 与 Godot 官方级兼容 |
| 人形绑骨+动作库 | **Mixamo**(免费网页) | 上传模型自动绑骨,几千个动作直接套,导出后丢回项目 |
| AI 生成 3D 粗模 | Meshy / Tripo(按次付费) | 半成品进 Blender 精修 |

## 免费素材库(AI 控制台可直接搜索)

- **Poly Haven**(CC0 模型/材质/HDRI)与 **ambientCG**(CC0 PBR 材质)—— `search_assets` 搜索后 `download_asset` **全自动下载导入**
- **Kenney**(CC0 2D/3D/音效)、**Quaternius**(CC0 3D 角色,自带动画)—— 搜索结果给官网链接,浏览器下载 zip 后一句话 `import_asset_zip` 导入(它们的下载地址不稳定,不做自动拉取)

每次下载/导入都会在素材目录写 `LICENSE.txt` 记录来源与许可。

## 引擎内命令(聊天里直接说人话即可,AI 会调用)

| 命令 | 干什么 |
|---|---|
| `search_assets` / `download_asset` / `import_asset_zip` | 搜索、自动下载、导入手动下载的 zip |
| `create_sprite_frames` | 精灵表切帧 → SpriteFrames(AnimatedSprite2D 动画) |
| `add_model_to_scene` | glb/gltf 模型实例进场景,并列出自带动画 |
| `apply_material` | 下载的 PBR 贴图组装成材质赋给模型 |
| `list_animations` / `play_animation` / `set_sprite_animation` | 查看/预览/设置动画 |
| `create_animation` | 程序化 K 关键帧(门开合、UI 渐入、简单过场) |
| `build_character_2d` + `sprite_frames` | 用切好的精灵表建**带动画**的 2D 角色(自动切 idle/run/jump) |
| `build_character_3d` + `model_scene` | 用带动画的 glb 建**带动画**的 3D 角色(自动识别 idle/run/walk/jump 片段) |

## 典型闭环示例

**3D:**"帮我找一个带动画的低模角色" → AI 返回 Quaternius 链接 → 你下载 zip → "导入 `C:\Users\me\Downloads\AnimatedCharacters.zip`,用里面的骑士建一个能跑的角色" → AI:import_asset_zip → build_character_3d(model_scene=...) → play_scene。

**2D:**Aseprite(+PixelLab)导出精灵表 png 放进项目 → "这张表是 8 列 2 行,前 4 帧是 idle 后 4 帧是 run,做个 2D 角色" → AI:create_sprite_frames → build_character_2d(sprite_frames=...)。

**材质:**"给地面来个砖墙材质" → AI:search_assets("brick") → download_asset(ambientcg) → apply_material。

**Mixamo:**Blender 里把模型导出 fbx → Mixamo 自动绑骨+选动作 → 导出 glTF → 丢进项目 → `add_model_to_scene` 接上。
