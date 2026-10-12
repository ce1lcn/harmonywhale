# HarmonyWhale

鸿蒙（HarmonyOS NEXT）平板上的 AI Agent **客户端**。模型由你自己配置的远程 API 提供，应用通过工具调用**直接操作真实设备** —— 启动应用、读取屏幕布局、点击与输入、读写文件、生成 Office 文档，并把每一步记录成可追溯的任务。

> ⚠️ 设备操作依赖开发者模式下的 HDC 自连接，目前只能在**你自己的平板**上使用。

## 功能

### 对话与任务

- 多会话聊天、流式回复、执行中补充要求、暂停 / 继续 / 取消
- 计划模式：先给计划草案，确认后才开始执行
- 上下文压缩：按配置窗口估算用量，达到 80% 触发摘要；原始记录仍完整落盘
- 多模型配置；API Key 与 MCP Token 用 HUKS AES-256-GCM 加密保存，密钥不导出

### 设备操作

- 屏幕截图与布局树读取，坐标统一采用 **0–1000** 归一化体系
- 点击、长按、双击、拖拽、滑动、按键与文本输入
- 应用启动与切换；支持小窗（悬浮窗）模式
- 产品级守卫：操作坐标落在桌面或其他受保护应用上会被拒绝

### 文件与文档

- 会话内文件读写与 `file_edit`；导入文件、另存导出，原件保留
- Word / Excel / PPT / PDF 的生成与内容提取（不重算公式，PPT 限基础文字内容）

### 扩展

- **技能（Skill）**：Markdown / ZIP 导入、查看、启停、移除与参考资料读取；不执行脚本
- **远程 MCP**：HTTPS Streamable HTTP 的初始化、工具发现、JSON / SSE 回复、调用与取消
- **记忆**：跨会话保存与检索

### 安全边界

- 危险动作按目标标签识别并确认，可授权「当前任务 / 同类动作 / 应用内同类动作」
- 确认后自动重新定位目标；任何一步不确定就停下，不盲点
- 插入与全选替换使用不同工具，避免语义歧义
- 任务与工具记录落盘；进程恢复时未完成任务先暂停，恢复前重新观察当前屏幕

## 技术栈

| 项 | 说明 |
| --- | --- |
| 平台 | HarmonyOS NEXT（Stage 模型） |
| 语言 / 框架 | ArkTS / ArkUI |
| 编译目标 | API 23（6.1.0） |
| 设备操作 | 应用内自实现的 HDC 协议，不依赖电脑 |
| 模型协议 | Chat Completions 与 Messages 两种，SSE 流式 |
| 第三方依赖 | 无 |

## 项目结构

```
entry/src/main/ets/
├── agent/            核心：串行任务循环、模型协议、设备工具、文件与格式、
│                     扩展（技能 / MCP / 记忆）、守卫与统计
│   ├── Engine.ets    任务循环与持久状态
│   ├── Model.ets     模型协议与流式解析
│   ├── Device.ets    设备连接、截图、布局与坐标动作
│   ├── Files.ets     文件读写、编辑与导入导出
│   ├── Office*.ets   Office 系列格式的读写
│   ├── Skills.ets    技能导入与启停
│   ├── Mcp.ets       远程 MCP 客户端
│   └── Store.ets     持久化与 HUKS 密钥
├── pages/            界面（聊天、时间线、设置、小窗、画布等）
└── entryability/     应用入口
scripts/              真机辅助脚本（点击守卫等）
tests/                离线测试
docs/                 技术文档
```

## 构建与运行

1. 用 DevEco Studio 打开本仓库根目录
2. 配置签名：`File → Project Structure → Signing Configs`，勾选 Automatically generate signature（需登录华为账号），或填入自己的证书与 Profile。**本仓库不包含任何签名材料**
3. 准备 `BuildSecrets.ets`（已在 `.gitignore` 中，不会提交）：
   - **构建时会自动生成**：`hvigorfile.ts` 会调用 `scripts/build-secrets.cjs`，把 `AppScope/app.json5` 里的版本号写进去；若设置了环境变量 `HARMONY_SEARCH_SECRETS`（指向工程外一个含 `bochaKey` 的 JSON5 文件），同时写入搜索 Key，否则该字段为空、联网搜索走无 Key 的降级通道
   - 也可以手动复制 `BuildSecrets.ets.example` 填写，但**下次构建若没有提供该环境变量，脚本会用空值重新生成、覆盖手填内容**
   - 该脚本需要能解析 `json5`：设置 `HVIGOR_JSON5` 指向它，或在项目环境里安装该模块
4. 在平板上开启开发者模式与无线调试，安装应用后选择一次信任
5. 在设置里填入模型的 HTTPS Base URL、模型名与 Key

## 离线测试

纯逻辑层不需要设备即可运行。测试通过 Node 的类型擦除直接加载工程里的 `.ets` 源码：

```powershell
# 指向任意可用的 TypeScript（例如 DevEco 自带的），或用 npm i typescript
$env:HVIGOR_TS='<DevEco SDK>\tools\hvigor\hvigor\node_modules\typescript\lib\typescript.js'
node tests/core.cjs      # 模型输出边界、SSE、暂停与恢复
node tests/harness.cjs   # 会话、计划、压缩
node tests/storage.cjs   # 持久化与凭据
node tests/files.cjs     # 文件读写与编辑
node tests/guard-0838.cjs
```

`tests/` 下还有覆盖引擎、格式、防护、时间线、用量统计等模块的用例；带 `native-` 前缀的用例需要真机，不在离线范围。

## 说明

- 本仓库**不包含**模型权重、API Key 或任何本机凭据；`BuildSecrets.ets` 已被 `.gitignore` 忽略
- 设备操作依赖开发者模式下的 HDC 自连接，每次重启应用可能需要在平板上重新确认信任；这是系统限制，不是应用可以绕过的
- 本应用是 **Agent 客户端**：推理由你自己配置的远程模型 API 提供，不在平板本地运行模型；会话、任务、工具注册与事件驱动的设计参考了 DeepSeek Harness（DSH），但不运行其插件或电脑端脚本
- 第三方来源与许可登记见 [docs/THIRD-PARTY.md](docs/THIRD-PARTY.md)

## License

本项目采用**非商业许可**：可以阅读、学习和修改，也可以在非商业目的下分发，但**任何商业用途都需要事先取得授权**。第三方部分（改写自 DeepSeek Harness 的代码）仍遵循其原有 MIT 许可，详见 [LICENSE](LICENSE) 与 [docs/THIRD-PARTY.md](docs/THIRD-PARTY.md)。
