# 界面改造 0.8.6 记录

依据：`docs/designs/2026-10-12-0.8.6-ui-overhaul.md`。只改界面层，Engine、Model、Device、Store、协议与数据契约未动。版本号在阶段 3 才改，本节不改版本、不打包。

## 阶段 1：主界面

改动文件：`entry/src/main/ets/pages/Index.ets`（sidebar、header、segment、composer、empty、titleMenu、plusPanel 及新增辅助方法）、`entry/src/main/ets/pages/PlusPanel.ets`。`settingsContent` 及设置相关 Builder、`agent/` 目录、`StatusBar.ets` 均未改动。

### 旧入口 → 新入口

| 控件 | 旧入口 | 新入口 |
|---|---|---|
| 侧栏顶部 | logo + 名字 + AGENT 黑标 | logo + 名字 + 右侧「收起侧栏」（`close_sidebar`）；AGENT 标删除 |
| 新会话行 | 运行中整行半透明，点击无反应 | 不再半透明；运行中点击提示「任务运行中，先暂停再新建会话」 |
| 搜索框 | 无清空方式 | 有输入时右侧出现 × 清空（`xmark`） |
| 收藏 | 滚动区列表第一行（`star`，带计数） | 搜索框下方快捷行「收藏」（`star`，选中蓝底） |
| 技能记忆 | 顶栏拼图图标（已删除） | 搜索框下方快捷行「技能记忆」（`puzzle`）→ `goSettings('skills')` |
| 用量 | 底部头像点击进入 | 搜索框下方快捷行「用量」（`gauge_with_dots_needle_33percent`）→ `panel='stats'` |
| 会话 / 多选 | 「多选」纯文字，点击区约 34 高 | 图标 + 文字「多选」，点击区 44 高；选择模式下显示「完成」 |
| 会话行三点 | 自绘三个圆点（34×34） | `ellipsis_circle` 图标（44×44）；菜单顺序不变：重命名 / 置顶 / 多选 / 删除 |
| 底部头像 | 头像（点击→用量） | 删除 |
| 底部模型/连接 | 头像旁「模型名 + 本机连接 · 版本号」，点整行→设置 | 「本机连接点 + 模型名」（点击→模型设置）；版本号不在侧栏显示（设置页仍有） |
| 底部齿轮 | 齿轮图标（点击→设置） | 「设置」齿轮 + 文字（`goSettings(当前分组)`，与原来 `panel='model'` 等价） |
| 侧栏开关（主区标题栏左侧） | 常显，开/收切换 | 侧栏收起时显示展开（`open_sidebar`）；侧栏展开时由侧栏顶部收起按钮负责 |
| 返回对话胶囊 | 标题栏左侧，非聊天页显示 | 位置不变（侧栏收起时它排在展开按钮之后） |
| 对话 / 轨迹标签 | 独占一行（52 宽标签） | 内嵌标题栏的分段控件（`segment`），仍调用 `panel=id`，切到对话时 `scrollToEnd` |
| 运行状态 | 状态点 + 文字（标题栏）；步数脚注在输入栏 | 状态点 + 「状态 · 已操作 N 步」（脚注并入标题栏） |
| 拼图图标 | 标题栏，进入技能页 | 删除（入口见「技能记忆」快捷行与「⋯」菜单） |
| 气泡图标菜单 | 导出当前会话 / 切换到小窗 | 「⋯」（`ellipsis_circle`）菜单：导出当前会话 / 收藏最后一条回复 / 清空本会话待办 / 设置会话目标… / 技能与记忆 / 设置 |
| 切换到小窗 | 气泡菜单内 | 标题栏独立按钮（`rectangle_inset_filled`），仍调用 `enterFloat()` |
| 侧栏收起时的新建 | 标题栏右侧 | 保留 |
| ＋ 弹窗 | 拍照 / 相册 / 文件 + 计划模式开关 + 目标行 | 拍照 / 相册 / 文件 + 底部「会话目标 设置 ›」文字链接（点击 `openGoal`）；计划开关移除 |
| 计划模式 | 藏在 ＋ 弹窗的开关 | 工具行「计划」胶囊（开启时蓝底白字），与原 `onPlan` 同一处理 `togglePlanMode()` |
| 文件胶囊 | 「对话 · N个文件」，点击无反应 | 「N 个文件」，仅本会话有文件时出现；点击→`settingsGroup='data'`、`panel='model'`（运行中提示，不跳转） |
| 「采用」建议 | 输入行文字按钮 | 输入区右上角「采用 Tab」胶囊（建议存在且输入为空、未运行时显示） |
| 待办条 | 对话页顶部（在消息列表上方） | 输入区上沿（仅有待办时出现）；对话页顶部移除 |
| 暂停胶囊 | 输入行，运行中显示 | 主按钮：运行中且输入为空时显示暂停图标，点击 `eng()?.pause()` |
| 继续 / 继续生成胶囊 | 输入行，已暂停显示 | 主按钮：已暂停且输入为空时显示播放图标，点击沿用 `start().catch(...)`；replyIncomplete 时无障碍文字为「继续生成」 |
| 取消胶囊 | 输入行，运行中或已暂停显示 | 主按钮左侧灰字「取消」（运行中或已暂停），点击 `pause('用户取消', true)` |
| 发送 / 停止按钮 | 圆形按钮；运行中图标为方块，点击=取消任务 | 圆形主按钮：空闲有内容=发送；运行中输入为空=暂停（不再取消）；运行中有输入=发送补充；已暂停=继续（有输入时为发送） |
| 模型胶囊 | 输入行右侧 | 工具行右侧，位于「取消」左侧；菜单不变（含「模型设置…」） |
| 空会话起手提示 | `ForEach([] as string[])`，无内容 | 4 个起手胶囊：读一个文件并总结 / 帮我做一份 PPT / 打开计算器算 123×45 / 记住：我习惯用简洁的回答；点击只填入输入框 |

### 验证结果

- **编译**：`$env:DEVECO_SDK_HOME='<DevEco SDK>\sdk'; $env:JAVA_HOME='<DevEco SDK>\jbr'; node <DevEco SDK>\tools\hvigor\bin\hvigorw.js assembleHap --no-daemon --offline`，结果 **BUILD SUCCESSFUL**。中途两次失败已修复（见下文「编译修复记录」）。
- **离线测试**：`PYTHONUTF8=1 python scripts/verify-drawing-release.py ui0860`，53 个脚本全部 exit=0，0 个失败。没有修改任何测试断言（没有测试读取 Index.ets 或 PlusPanel.ets 的文案）。
- **id 核对**：`grep -ho "\.id('[^']*'" entry/src/main/ets/pages/*.ets | sort -u` 共 37 个，与 `artifacts/ui-backup/ids-08516.txt` 的 37 个逐条一致；缺失 0 个，新增 0 个。
- **真机 / 视觉**：未验证。本阶段未操作平板，布局、点击区、图标渲染均未在设备上确认。

### 编译修复记录

1. 第一次编译：6 个 ArkTS 错误。
   - CompactChat.ets（小窗）也调用 `PlusPanel({planning, onPlan})`，删除这两个接口导致报错。修复：PlusPanel 保留 `planning` / `onPlan`，新增 `showPlan` 开关（默认 true，小窗行为不变）；主界面的 ＋ 弹窗传 `showPlan:false`。
   - 三个符号名编译器不认：`gauge`、`ellipsis`、`pip`。原因见下文「符号核对方法」。改为 `gauge_with_dots_needle_33percent`、`ellipsis_circle`、`rectangle_inset_filled`。
2. 第二次编译：PlusPanel.ets `if` 块后的 `;` 被报 "Only UI component syntax can be written here"。修复：去掉分号，换行。

### 符号核对方法（与规格不同之处）

- 规格要求 grep `<DevEco SDK>\sdk\default\hms\ets\sysResource.js`。该文件**没有 symbol 段**（只有 string / media / color / float），不能用于核对符号名。
- 编译器真正使用的符号名单在 `<DevEco SDK>\sdk\default\openharmony\ets\build-tools\ets-loader\sysResource.js` 的 `symbol:` 段（约 3971 个名字）。本阶段以它为准。
- 我另外用过 `HMSymbolVF.ttf` 做子串 grep，结果不可靠（`ellipsis` 命中的是 `ellipsis_message`），已弃用。

### 自行做的取舍

1. 已暂停且输入框有内容时，主按钮显示「发送」并走 `send()`（处理回答或续跑），不显示「继续」。规格只写了"已暂停=继续"，未写有输入时的情况。
2. 运行中输入为空时的主按钮改为 `pause()`（暂停），原来是 `pause('用户取消', true)`（取消）。这是规格要求，属于行为变化，已在上表标明。
3. 侧栏快捷行（收藏 / 技能记忆 / 用量）和新会话在运行中点击时，统一 toast 提示，不再静默失效。
4. 「收藏最后一条回复」菜单项始终显示；没有已完成回复时点击提示，不在菜单构建时遍历时间线（避免流式刷新时的额外开销）。
5. 「清空本会话待办」在运行中或无待办时提示，不静默返回。
6. 侧栏底部「模型名」点击进入「模型」分组；「设置」齿轮保留当前分组（与原来行为一致）。
7. 小窗（CompactChat）未改，仍使用 PlusPanel 的计划开关（`showPlan` 默认值）。
8. PlusPanel 底部目标行的文字由「目标」改为「会话目标」，便于辨认。
9. 收起侧栏时的展开按钮只在非紧凑（非小窗宽度）时显示，避免无效按钮。

### 遗留问题

1. `StatusBar.ets`（未改，不在本阶段文件清单内）仍有「暂停」「继续」「压缩上下文」按钮，与主按钮的暂停 / 继续重复。id `status_pause`、`status_resume` 已保留。建议阶段 3 处理 StatusBar 时删减。
2. 版本号仍为阶段前的值（阶段 3 才改）。
3. 本阶段未打包，未生成 `releases/` 产物。
4. 设置相关 Builder（`settingsContent` 等）未动，阶段 2 处理。
5. 布局、触控点击区（≥44）、符号渲染需要真机或后续阶段的视觉验证。

## 阶段 2：设置与技能记忆

改动文件：`entry/src/main/ets/pages/SettingsShell.ets`（分组、导航图标、旧 id 映射）、`entry/src/main/ets/pages/SkillMemoryPanel.ets`（技能列表项）、`entry/src/main/ets/pages/Index.ets`（`settingsPage` 到 `settingsAbout` 之间的设置 Builder，`goSettings`，新增 `settingsKey`、`skillMoreMenu`、`foldHead`，状态 `skillTab`、`advGeneral`、`advModel`、`devAbout`）。`agent/` 未改；侧栏、顶栏、输入栏、聊天页、`Theme.ets` 未改；版本号未改（仍为 0.8.5.16，阶段 3 才改）；未打包。

### 分组：11 → 8

| 旧分组（id） | 新位置 |
|---|---|
| 通用（general） | 通用（general） |
| 模型（model） | 模型（model） |
| 执行与权限（execution） | 权限与预算（execution） |
| 工具（tools） | 工具与扩展（tools）上半 |
| 技能（skills） | 技能与记忆（skills）「技能」分段 |
| 记忆（memory） | 技能与记忆（skills）「记忆」分段；`goSettings('memory')` 同时切到记忆分段 |
| 扩展（MCP）（mcp） | 工具与扩展（tools）下半 |
| 设备连接（connection） | 连接与关于（about）上半 |
| 数据与隐私（data） | 文件与数据（data） |
| 用量（usage） | 用量（usage），不变 |
| 关于（about） | 连接与关于（about）版本与开发者 |

旧 id 兼容：`SettingsShell.ets` 的 `settingsGroupId()` 把 memory→skills、mcp→tools、connection→about；`goSettings()` 与分组读取都经过它。别处写入 `skills`、`model`、`data` 的代码未改。

### 旧控件 → 新位置

| 旧控件（旧分组） | 新位置 | 备注 |
|---|---|---|
| 字号滑块（通用） | 通用 ▸ 显示 | 不变 |
| 任务结束后回到大肥鱼（通用） | 通用 ▸ 行为 | 不变 |
| 小窗截图隐形策略 `float_strategy_*`（通用） | 通用 ▸ 小窗 ▸ 高级（默认折叠） | id 不变 |
| 切换到小窗（顶栏气泡菜单，阶段 1 已移到顶栏） | 通用 ▸ 小窗「切换到小窗」 | 调用 `enterFloat()` |
| 配置列表、新配置（模型） | 模型 ▸ 模型配置 | 不变 |
| 配置名称、模型（模型） | 模型 ▸ 模型配置 | 不变 |
| Base URL（模型） | 模型 ▸ 模型配置 | 标签注明「必须以 https:// 开头」，与 `saveProfile` 校验一致 |
| 协议切换（模型） | 模型 ▸ 模型配置 | 增加「协议」标签 |
| API Key 输入（模型） | 模型 ▸ 模型配置 | 状态文字不变 |
| 删除此密钥（模型，原为胶囊按钮） | 模型 ▸ Key 行右侧红字 | 危险操作；原逻辑无确认，未新增 |
| 保存并使用（模型） | 模型页底部固定行 | 结果沿用 `this.message` 顶部提示条 |
| 上下文窗口、单次输出上限（模型） | 模型 ▸ 高级（默认折叠） | |
| 思考强度 `effort_*`（模型） | 模型 ▸ 高级 | id 不变 |
| 图片输入、工具调用开关（模型） | 模型 ▸ 高级 | |
| 密钥存储自检（模型） | 模型 ▸ 高级 | |
| 下载大小上限（模型） | 权限与预算 ▸ 下载 | 按规格搬迁，校验原样 |
| 每段操作上限、每段等效用量（权限与预算） | 权限与预算 ▸ 任务预算 | 各加标签与范围说明，校验原样 |
| 同类授权说明（权限与预算） | 权限与预算 ▸ 同类授权 | 文字不变 |
| 导入 Markdown / ZIP（技能） | 技能与记忆 ▸ 技能「导入」 | 灰字注明支持 Markdown 或 ZIP |
| 保存示例（技能） | 技能与记忆 ▸ 技能 ⋯ 菜单 | `ellipsis_circle` |
| 技能启用 / 停用（技能） | 技能列表行右侧开关 | 调用 `skillSetEnabled` |
| 技能查看（技能） | 展开区「查看全文」 | 仍写入 `message`，截断 2000 字 |
| 技能删除、历史回滚（技能） | 展开区 | 沿用 `onDelete` / `onRollback` |
| 记忆列表与删除（记忆） | 技能与记忆 ▸ 记忆 | 删除改红字 |
| 工具开关（工具） | 工具与扩展 ▸ 工具 | 逻辑不变 |
| MCP 添加（扩展） | 工具与扩展 ▸ MCP 服务 | 地址标签「HTTPS Streamable HTTP 地址」改为「服务地址（https://）」，协议名移出主界面 |
| MCP 启用 / 停用、删除（扩展） | 工具与扩展 ▸ MCP 服务 | 删除改红字 |
| 本会话文件 另存 / 删除（数据） | 文件与数据 ▸ 本会话文件 | 运行中删除按钮半透明且不响应 |
| 导出当前会话（数据） | 文件与数据 ▸ 导出 | 顶栏「⋯」菜单中仍有 |
| 清理历史截图（数据） | 文件与数据 ▸ 历史截图 | 红字；原逻辑无确认，未新增 |
| 本机连接状态、本机重连（连接） | 连接与关于 ▸ 本机连接 | 逻辑不变 |
| 版本信息（关于） | 连接与关于 ▸ 版本 | |
| 执行层测试页、联网测试页、笔输入探针（关于） | 连接与关于 ▸ 开发者（默认折叠） | 改为胶囊按钮，路由不变 |
| 用量（用量） | 用量 | 不变 |

### 验证结果

- **编译**：`hvigorw assembleHap --offline` 结果 **BUILD SUCCESSFUL**，首次即通过；改一处标签文案后再次编译，仍 BUILD SUCCESSFUL。ArkTS 警告为已有的 `pushUrl`、`getContext` 弃用提示，本阶段未新增错误。
- **离线测试**：`PYTHONUTF8=1 python scripts/verify-drawing-release.py ui0860b`，53 个脚本全部 exit=0。没有修改任何断言（测试不读取设置页源码）。`native-device.cjs` 按脚本排除，未运行。
- **id 核对**：`grep -ho "\.id('[^']*'" entry/src/main/ets/pages/*.ets | sort -u` 共 37 个，与 `artifacts/ui-backup/ids-08516.txt` 逐条一致，缺失 0 个，新增 0 个。
- **功能接线核对（grep，未逐个点击）**：上表每个回调在 Index.ets、SkillMemoryPanel.ets 中仍有调用处。
- **符号核对**：pages 目录所有页面使用的 48 个 `sys.symbol.*` 名称（含阶段 1），均在 `<DevEco SDK>\sdk\default\openharmony\ets\build-tools\ets-loader\sysResource.js` 的 symbol 段中匹配到。
- **真机 / 视觉**：未验证。未操作平板，折叠展开、模型页底部固定、技能列表展开、44 点击区、图标渲染均未在设备上确认。

### 自行做的取舍

1. 规格要求核对 `hms\ets\sysResource.js`，该文件没有 symbol 段，沿用阶段 1 结论，改用 `openharmony` 那份核对。
2. 「技能与记忆」顶部分段用 `@State skillTab`（在 Index 中）；记忆分段下不显示「导入」和 ⋯ 菜单。
3. 折叠区（高级、开发者）默认折叠，状态为 Index 的 `advGeneral`、`advModel`、`devAbout`，不持久化。
4. 「去对话里改」只切到对话页并预填输入框，不发送，运行中也可点。
5. 每段操作上限的单位在 Engine 中未核实，标签不带单位；每段等效用量沿用原文案「百万」。
6. 模型页的「保存并使用」固定在底部；保存结果仍显示在顶部提示条（`notice`），底部行不另加提示，避免两处重复。
7. 技能列表沿用 `@Prop @Watch('reload') rev` 与 `copySkill`，未改刷新机制。

### 遗留问题

1. 「保存并使用」的成功提示只在顶部提示条，用户在底部点击时若不看顶部，需真机确认是否足够。
2. `SkillMemoryPanel.ets` 的 `originText`、`skillStateText` 已无调用方，仍作为导出保留，阶段 3 可清理。
3. 版本号仍为 0.8.5.16，阶段 3 才改；本阶段未打包，无 `releases/` 产物。
4. `StatusBar.ets` 未改，其「暂停 / 继续 / 压缩上下文」按钮仍与主按钮重复，留给阶段 3。
5. 全局 44 点击区（如 `pill` 高 36）在阶段 3 统一处理，本阶段只在新增的文字按钮上保证 44 高。

## 阶段 3：小窗、卡片、版本与打包

依据：`docs/designs/2026-10-12-0.8.6-ui-overhaul.md` 第 4 节。版本升到 **0.8.6.0 / 8600**。Engine、Model、Device、Store、协议未动；`agent/` 下只有 `scripts/build-secrets.cjs` 重新生成的 `BuildSecrets.ets`。未安装到平板，未运行 hdc、safe-tap、uitest、native-device。

改动文件：`pages/StatusBar.ets`、`pages/CompactChat.ets`、`pages/Cards.ets`、`pages/ApprovalDialog.ets`，`pages/Index.ets` 的 `pill`、`softChip`、`approval`、输入区工具行、动作行用量胶囊，`AppScope/app.json5`。

### 旧入口 → 新入口

| 控件 | 旧 | 新 |
|---|---|---|
| 状态栏「已暂停」胶囊（`status_pause`） | 显示「已暂停 · 原因」；点开的弹层里有「继续」按钮（`status_resume`） | 文字改为「已暂停」；点开只显示暂停原因和一句提示。继续只由输入栏主按钮负责；`status_resume` 保留为 0 尺寸占位 |
| 状态栏运行中的「暂停」 | 代码中不存在（规格写有，实际没有）；运行中只有时间胶囊 | 不变 |
| 状态栏 时间 / Token / 上下文 胶囊 | 高约 28 | 外层 44 高点击区，视觉与 popup 行为不变 |
| 小窗 头部「暂停」（`float_pause`） | 标题行右侧胶囊 | 输入行主按钮（运行中且输入为空），调用 `eng()?.pause()` |
| 小窗 头部「继续」（`float_resume`） | 标题行右侧胶囊 | 输入行主按钮（已暂停且输入为空），调用 `onResume()` |
| 小窗 头部「停止」（`float_stop`） | 标题行带边框胶囊 | 输入行朴素文字「取消」（灰字，运行中或已暂停），调用不变 `pause('用户取消', true)` |
| 小窗 发送（`float_send`） | 输入行右侧，只发送 | 输入行主按钮随状态：有输入或空闲=发送（`float_send`）；运行中且输入为空=暂停（`float_pause`）；已暂停且输入为空=继续（`float_resume`） |
| 小窗 菜单（`float_menu`） | 44×44 | 不变（规格要求 ≥44，已满足） |
| 小窗 确认卡片「同意」「拒绝」（`float_approve`、`float_reject`） | 高 34；同意在左，等宽 | 拒绝在左、同意在右，等宽；外层 44 高点击区，视觉仍 34 高；文案「同意」不变 |
| 主界面 确认卡片（Index `approval`） | 「同意此操作」在左，「拒绝」在右，宽度不等 | 「拒绝」在左、「同意此操作」在右，等宽，pill 外层 44 |
| 桌面确认弹窗（`ApprovalDialog`） | 默认宽度；「拒绝」在左；默认高 40 | 两个按钮等宽、高 44，同意在右；「取消任务」高 44 |
| 文件卡片 「预览 / 收起」「删除」「另存为」 | 文字高 44、宽为文字宽，文字顶部对齐 | 外层 44 高、左右各 10 的点击区，文字大小不变，改为垂直居中 |
| 学会卡片 「展开 / 收起」「撤销」 | 同上 | 同上 |
| 通用胶囊 `pill`（确认、设置、目标、技能、用量等页面的按钮） | Button 高 36 | 外层 44 点击区；内层 36 高胶囊视觉不变。Button 换成 Row，失去按压高亮 |
| 通用 `softChip`（「返回对话」「N 个文件」） | 高约 28 | 外层 44 点击区 |
| 输入区「计划」胶囊 | 高 36 | 外层 44 点击区 |
| 输入区「模型」胶囊（菜单） | 高 36 | 外层 44 点击区，菜单不变 |
| 输入区「取消」 | 高 40 | 44 |
| 输入区「采用 Tab」 | 文字高约 26 | 外层 44，右边距保持 14 |
| 动作行「用量 N tok」 | 高约 31 | 44，文字垂直居中 |

规格第 4 节提到的「撤销」「打开」：文件卡片没有「打开」按钮，只有「预览 / 收起」「删除」「另存为」；学会卡片有「展开 / 收起」「撤销」，都已覆盖。

### 验证结果

- **编译**：`hvigorw assembleHap --no-daemon --offline` 结果 **BUILD SUCCESSFUL**（16 s 675 ms）。日志无 ERROR。WARN 是已有的 deprecated 提示（`pushUrl`、`getContext`、`back`、`screenX/screenY`）。日志：`artifacts/build-08600-dev.log`。
- **离线测试**：`PYTHONUTF8=1 python scripts/verify-drawing-release.py ui0860c`，53 个脚本全部 exit=0，未修改任何断言。日志：`artifacts/tests-ui0860c.log`、`artifacts/tests-ui0860c.json`。
- **id 核对**：`grep -ho "\.id('[^']*'" entry/src/main/ets/pages/*.ets | sort -u` 共 37 个，与 `artifacts/ui-backup/ids-08516.txt` 逐条一致，缺失 0，新增 0。`float_pause`、`float_resume`、`float_send` 三者按模式在输入行互斥出现，其余 float_* 全部存在；`status_pause`、`status_resume`、`status_time`、`status_token`、`status_ctx`、`status_compress` 存在。
- **打包**：`releases/HarmonyWhale-0.8.6.0/HarmonyWhale-0.8.6.0-signed.hap`，SHA256 `685aeeefaa0908f06643685477b63977a0c2f49c2fe2cbb9604bad00c27c5643`。目录原本不存在，新建后复制，未覆盖任何已有目录。
- **解包核对**（解到 scratchpad 临时目录，不在工程内）：`bundleName=com.harmonyloom.selfhdcprobe`；`versionName=0.8.6.0`；`versionCode=8600`；module `entry`；abilities 只有 `ProbeAbility`；无 `extensionAbilities`；`buildMode=debug`；`minAPIVersion` / `targetAPIVersion` 均为 60100023，与 0.8.5.16 相同。
- **签名核验**：`hap-sign-tool.jar verify-app` 成功（Digest verify true，证书链 3 张）。证书的 Subject、Issuer、SHA256、Validity 与 `artifacts/signature-08516.log` 逐条一致。日志：`artifacts/signature-08600.log`。核验结果写入 `releases/HarmonyWhale-0.8.6.0/verification.json`。
- **真机 / 视觉**：未验证。布局、44 点击区、状态栏高度变化、确认卡片、文件卡片文字位置均未在设备上确认。

### 自行做的取舍

1. 点击区用外层容器实现，不靠放大 Button：Button 自己吃掉点击事件，父容器的 onClick 收不到。pill、确认按钮、文件卡片按钮改为 Row 作为点击根，代价是失去 Button 的按压高亮。
2. 小窗主按钮的 id 随模式切换，同一时刻只存在一个。依赖固定 `float_pause` 的旧脚本需要先判断当前状态。
3. 「同意」在小窗保留原文案；主界面与桌面弹窗仍用「同意此操作」。
4. 文件卡片、学会卡片的文字由顶部对齐改为垂直居中（原来的 `height(44)` 配合 `textAlign` 只做水平居中，文字实际位于顶部）。视觉上有轻微变化。
5. 桌面 `ApprovalDialog` 按钮默认高 40，改为 44。
6. 状态栏 4 个胶囊、输入区工具行、通用 pill 外层变为 44 高，底栏和工具行整体变高，真机需要看一眼布局是否可接受。
7. 状态栏的「继续」只删掉了弹层里的按钮；pill 的文字改为「已暂停」，原因保留在弹层里。
8. 版本号直接用 0.8.6.0，没有使用 0.8.6.1 之类的中间号。

### 遗留问题

1. **搜索密钥可能被清空（需决定）**。规格要求运行 `node scripts/build-secrets.cjs` 且不设置 `HARMONY_SEARCH_SECRETS`。该脚本在无输入时把 `BOCHA_KEY` 写为空串，因此本次生成的 `BuildSecrets.ets` 中搜索密钥为空。若 0.8.5.16 依赖该密钥提供联网搜索，本包的联网搜索将不可用。我没有读取原文件，无法确认旧值是否为空。如需保留，应使用 `HARMONY_SEARCH_SECRETS` 重新生成并以新版本号重新打包。
2. **签名证书即将过期**。Development 证书有效期到 2026-10-18 00:40:55，按今天 2026-10-12 计算约 6 天后到期。到期后新装包的校验可能失败，需要在到期前确认或更换证书。
3. 构建为 debug（`buildMode=debug`，与 0.8.5.16 一致）。
4. 未逐个审查 `Index.ets` 的其他可点元素（如侧栏搜索「×」、设置页行内小按钮），只处理了通用 Builder 和本阶段规格列出的控件。
5. `SkillMemoryPanel.ets` 的 `originText`、`skillStateText` 仍未清理（阶段 2 遗留，本阶段未处理）。

## 阶段 4：0.8.6.2 用户参考图补充

依据：`docs/designs/2026-10-12-0.8.6-ui-overhaul.md` 第 6 节（6.1–6.6），并按协调方的两次修订执行：6.3 命令菜单改为两段布局（顶部三个图标入口 + 三行列表，去掉权限 / 模型 / 导出行）；6.4 目标模式只开启输入框的 `/目标` 前缀，不跳转、不调用 `openGoal()`。版本 0.8.6.2 / 8602。

改动文件：`pages/Index.ets`（侧栏底部、输入区、模型胶囊、⋯ 菜单、send、newChat、openSession）、`pages/StatusBar.ets`（整文件重写，id 与弹层逻辑不变）、新建 `pages/CommandMenu.ets`。`PlusPanel.ets`、`CompactChat.ets`、`agent/` 未改。版本号与 `BuildSecrets.ets` 的 APP_VERSION 已更新。

### 需求 → 实现位置 → 验证方式

| 条款 | 实现位置 | 验证方式 |
|---|---|---|
| 6.1 侧栏左下角头像 | `Index.ets` `sidebar()` 底部行：40 圆形头像（`app.media.avatar`，44 点击区）→ `goPanel('stats')`；中间两行「模型名 / 连接点 + 本机已连接 · 等待连接」→ `goSettings('model')`；右侧「设置」齿轮保持原行为 | 编译通过；资源文件 `base/media/avatar.jpg` 存在；视觉与点击未验证 |
| 6.2 状态条图标 | `StatusBar.ets` `build()`：`timer`、`square_stack_3d` 用 `SymbolGlyph`；上下文为 `Progress({type:ProgressType.Ring})`，16×16，`style({strokeWidth:2.5})`，≥80% 橙色，底圈 `LINE`；三项平铺无边框、灰字、`justifyContent(Center)`，间距 14；运行中时间保持蓝字 | 编译通过（SDK `progress.d.ts` 的 `RingStyleOptions.strokeWidth` 自 API 10 起可用）；符号名已在 SDK symbol 段核对；id `status_time/token/ctx/pause/resume/compress` 全部保留；未验证真机外观 |
| 6.3 命令菜单（修订） | 新建 `pages/CommandMenu.ets`：`commandRows()`、`commandEntries()` 纯函数 + `CommandMenu` 组件；`Index.ets` `commandPopup()`、`runCommand()`、`composerChange()`；「＋」与输入框开头 `/` 共用 `bindPopup`，`focusable:false`，宽 380，圆角 16 | 编译通过；临时脚本（scratchpad，未入库）验证过滤：空串全部、「目标 / 计划 / 压 / goal / plan」命中对应行、无匹配为空、运行中全部置灰；未验证真机弹出与焦点 |
| 6.3 顶部图标入口 | 拍照 `pickImages(true)`、相册 `pickImages(false)`、文件 `importOffice()`，圆形底图标 + 文字（样式沿用旧 PlusPanel entry）；`/` 过滤时隐藏 | 同上 |
| 6.3 列表行 | 目标模式 → `enterGoalMode()`（见 6.4）；计划模式 → `togglePlanMode()`；压缩上下文 → `compressContext()`；灰色英文 key 与右侧说明 | 同上；说明文字：目标行在已有目标时显示「当前：<前 20 字>」 |
| 6.3 运行中 | `commandRows/commandEntries` 的 `enabled=!running`，置灰；点击统一 `toast('任务运行中，先暂停再操作')`，不执行 | 过滤脚本已覆盖；真机未验证 |
| 6.3 `/` 触发 | `composerChange()`：输入以 `/` 开头且无空白时 `slashMode=true`、`slashQuery=v.slice(1)`，有匹配才 `plusOpen=true`；否则收起。选中后 `runCommand()` 先清掉输入框的 `/…` 文本 | 代码审读；未验证真机 |
| 6.4 `/目标` 前缀 | `composerGoal` 状态；输入区 `Row{ /计划 token, /目标 token, TextArea }`，蓝色前缀；点击 token 或输入为空按退格（`KEYCODE_DEL`）移除，计划 token 同时调用 `togglePlanMode()` 关闭 | 编译通过；未验证真机 |
| 6.4 目标模式不跳转 | `enterGoalMode()` 只设置 `composerGoal=true`，不调用 `openGoal()`，焦点留在输入框；⋯ 菜单「设置会话目标…」改为「目标模式」（`panel='chat'` + `enterGoalMode()`）。输入栏链路中已无 `openGoal()` 调用 | `grep openGoal` 结果：仅剩 `openGoal()` 定义、顶部 harnessBar「目标：…」行的点击（查看 / 结束已有目标）、小窗 `CompactChat` 的 `onGoal`，均为既有入口，未删 |
| 6.4 发送 | `send()`：`composerGoal` 时先 `engine.setGoal(input,[],[])`（运行中拒绝并提示；失败保留输入并提示），之后走原有流程；在 `engine.start(...)` 之前清除 `composerGoal`。`newChat()`、`openSession()` 同样清除 | 编译通过；Engine `setGoal` 签名与抛错条件已读源码核对；未验证真机 |
| 6.4 placeholder | `inputPlaceholder()`：运行中「补充要求，下一步生效」；目标「输入目标，智能体将持续执行」；计划「描述要完成的任务，先出计划再执行」；否则建议文字或「发消息或创建任务，/ 调用指令」 | 代码审读 |
| 6.5 模型胶囊就地菜单 | 工具行模型胶囊：`Text(activeModel)` + 灰色 `effortName()`（`effortOf(profile)`，Off/Low/High/Max）+ `chevron_down`；`bindPopup` 的 `modelPopup()`，根页 → 模型子页（列表 ✓，末行「管理模型配置…」）/ 推理等级子页（四档 ✓）；每次打开从根页开始；运行中可看，切换提示 | 编译通过；`Engine.save()` 调用构造时传入的 `changed` 回调（即 `revision++`），已源码核实，故未额外 `revision++`；未验证真机 |
| 6.5 旧入口保留 | `profileMenu()`、设置页模型配置、小窗模型入口均未删除（`profileMenu()` 已不被调用，保留） | 代码审读 |
| 6.6 编译 | `hvigorw assembleHap --no-daemon --offline`：BUILD SUCCESSFUL（13 s 830 ms）。日志 `artifacts/build-08602-dev.log`；WARN 6 条与 0.8.6.1 相同（`getContext`、`pushUrl`、两处 `deleteFile`/`deleteSessions` 既有提示） | 已验证 |
| 6.6 离线测试 | `PYTHONUTF8=1 python scripts/verify-drawing-release.py ui0862`：53/53 exit=0，没有修改任何断言（测试不读取界面源码） | 已验证 |
| 6.6 旧 id | `grep -ho "\.id('[^']*'" pages/*.ets | sort -u` 共 37 个，与 `artifacts/ui-backup/ids-08516.txt` 逐条一致，缺失 0，新增 0 | 已验证 |
| 6.6 版本与打包 | `AppScope/app.json5`：versionName 0.8.6.2、versionCode 8602；`node scripts/build-secrets.cjs` 重新生成（未设置 `HARMONY_SEARCH_SECRETS`，未读取除 APP_VERSION 外的内容）；产物 `releases/HarmonyWhale-0.8.6.2/HarmonyWhale-0.8.6.2-signed.hap`，SHA256 `09806df39488846d87cef8e984bbc11c90462a9afe1a6200458ddb2b6b2dd1ce` | 已验证（见下） |
| 6.6 解包核对 | 临时目录（scratchpad）解包：bundleName `com.harmonyloom.selfhdcprobe`，versionName 0.8.6.2，versionCode 8602，module `entry`，abilities 仅 `ProbeAbility`，无 extensionAbilities，`minAPIVersion/targetAPIVersion` 60100023（与 0.8.6.1 相同） | 已验证 |
| 6.6 签名核验 | `hap-sign-tool.jar verify-app -inFile … -outCertChain … -outProfile …`：verify-app success；去掉时间戳后与 `artifacts/signature-08601.log` 逐行一致（39 行）。日志 `artifacts/signature-08602.log`；`releases/HarmonyWhale-0.8.6.2/verification.json` 已写入 | 已验证 |
| 不安装 | 未运行 hdc、safe-tap、uitest、native-device；未安装到平板 | 本阶段不涉及真机 |

### 取舍

1. 计划模式行是切换：未开启时开启，已开启时关闭（与原加号弹窗的开关一致），说明文字沿用协调方给出的「进入或退出计划模式」。关闭也可用计划 token 的点击或退格。
2. ⋯ 菜单的「设置会话目标…」改为「目标模式」，不再打开目标页；`goalPage` 本身保留，顶部 harnessBar 的「目标：…」行仍可点进去查看或结束目标。
3. 权限 / 模型 / 导出三行从命令菜单移除（按修订）。权限在设置页的「权限与预算」，导出在 ⋯ 菜单。
4. 运行中输入「/」仍会弹出菜单，列表行置灰；选中任一行时 `runCommand()` 先清掉输入框里的 `/…` 过滤文本，然后只提示「任务运行中，先暂停再操作」，不执行动作。
5. 模型子页在运行中点击模型项只提示，菜单保持打开。
6. 侧栏模型名与连接状态两行点击仍进入模型设置（规格未写，沿用阶段 1 的行为）。头像 40 外层 44 点击区。
7. `send()` 中目标校验在 OCR 之前执行：若之后 OCR 失败，目标已写入会话，但 `/目标` 前缀仍保留，再次发送会重新 `setGoal`（幂等）。
8. 待回答问题（paused 且有 AskUser）时，发送走「回答」分支，`/目标` 前缀保留，不会被当成目标。
9. 菜单选项 `enabled` 与 Index 的运行判断共用 `isRunning()`，没有另设状态。
10. 图标入口与列表行的 `opacity` 置灰仅为视觉，仍可点击以显示提示。
11. 去掉了 `PlusPanel` 在主界面的使用（`plusPanel()` builder 与 import 已删）；`PlusPanel.ets` 文件本身未改，小窗仍使用它。

### 遗留

1. **真机未验证**：头像与侧栏布局、状态条平铺居中与圆环外观、命令菜单弹出位置与焦点（`focusable:false` 是否保住输入法）、`/` 过滤与退格移除 token、模型气泡的层级与刷新、44 点击区，均未在设备上确认。
2. **搜索密钥（沿用 0.8.6.0 的风险，未核实）**：本次仍按规格不设置 `HARMONY_SEARCH_SECRETS` 运行 `build-secrets.cjs`。0.8.6.0 记录显示该脚本在无输入时把 `BOCHA_KEY` 写为空串，本次未读取 `BuildSecrets.ets` 内容，无法确认。如需保留联网搜索密钥，需用原密钥重新生成并以新版本号重新打包。
3. **签名证书即将到期**：Development 证书有效期到 2026-10-18 00:40:55，按今天 2026-10-12 计算约 6 天。
4. 构建为 debug（与前几版一致）。
5. `profileMenu()` 已无调用方，保留未删（规格要求旧入口不删）；`SkillMemoryPanel.ets` 的 `originText`、`skillStateText` 仍是阶段 2 遗留。

## 阶段 5：0.8.6.3 真机后的三处调整

依据：`docs/designs/2026-10-12-0.8.6-ui-overhaul.md` 第 7 节（7.1–7.5）。协调方补充：7.4 要穷举所有深蓝实心文字胶囊，见下文审计表。版本 **0.8.6.3 / 8603**。

改动文件：`pages/Theme.ets`（新增 `BLUE_DEEP`）、`pages/Index.ets`、`pages/CompactChat.ets`、`pages/StatusBar.ets`、`pages/ApprovalDialog.ets`、`pages/SkillMemoryPanel.ets`、`pages/Cards.ets`、`pages/SettingsShell.ets`，`AppScope/app.json5`，`BuildSecrets.ets`（脚本生成）。未改：`agent/`、`CommandMenu.ets`（无蓝色元素）、`PlusPanel.ets`、`TodoBar.ets`、`MarkdownView.ets`（只有文字链接，无实心蓝）、ExecutionFixture / WebSpike / PenProbe。未安装，未操作平板。

行号：下文「改前行号」指 `artifacts/ui-backup/pages-0862/` 中的源码行号。

### 7.1 加号菜单左对齐

| 项 | 改前 | 改后 |
|---|---|---|
| 锚点 | `＋` 按钮（Index.ets 改前 690 行），`Placement.Top`，弹窗以按钮为中心，左缘压到侧栏 | `composer()` 最外层 Column（Index.ets 改前 699 行，即输入框圆角容器），`Placement.TopLeft`，左缘与输入框左缘对齐 |
| 偏移 | 无 | `offset:{x:0,y:-6}`（SDK `PopupOptions.offset`，规格允许；方向未在真机核对） |
| 其它选项 | `popupColor:WHITE, enableArrow:false, radius:16, focusable:false, onStateChange` | 不变 |
| 显示条件 | `plusOpen` / `slashMode` | 不变，外层容器没有 onClick，点 composer 其它区域不会弹出 |

`＋` 按钮只保留 `onClick` 切换 `plusOpen`。`/` 触发沿用同一个弹窗。模型气泡（`modelPopup`）未改。小窗 CompactChat 的 PlusPanel 未改。

### 7.2 「采用 Tab」：不改

输入区右上角「采用 Tab」胶囊（Index.ets 改前 `采用 Tab` 文字行）保留，位置与样式不变。

### 7.3 输入栏下移、压缩垂直空间

| 规格项 | 改前 | 改后 | 位置 |
|---|---|---|---|
| `bottomGap()` | `Math.max(10, bottomInset*0.5)` | `Math.max(6, bottomInset*0.35)` | Index.ets 改前 203 行 |
| 侧栏与设置页底栏 | 共用 `bottomGap()` | 新增 `legacyGap()` 保留旧值 `Math.max(10, bottomInset*0.5)`，侧栏底部与设置页底栏改用它 | Index.ets 改前 444、1002 行 |
| 聊天输入区底部 | `bottomGap()` | 新值 | Index.ets 改前 720 行 |
| 轨迹 / 用量 / 收藏页底部 padding | `bottomGap()+14` | 随新 `bottomGap()` | Index.ets 改前 790、860、887 行 |
| 输入框 top padding | 14 | 10 | Index.ets 改前 684 行 |
| 「/计划」「/目标」token 上边距 | 14 | 10（与输入框文字对齐） | Index.ets 改前 682、683 行 |
| TextArea minHeight | 48 | 44 | Index.ets 改前 684 行 |
| 工具行 padding | `bottom:10, top:6` | `bottom:8, top:4` | Index.ets 改前 698 行 |
| 工具行按钮外层 | 44 | 44（不变） | `＋`、模型胶囊、取消、主按钮 |

未按规格执行的两处（与「不让可点击元素外层点击区低于 44」的硬要求冲突，或与代码不符）：

1. **StatusBar 外层点击区 44 → 36：未执行。** 四个胶囊（`status_pause` / `status_time` / `status_token` / `status_ctx`）保持 `height(44)`。
2. **StatusBar 上边距 6 → 2：未执行。** 代码中 StatusBar 根 Row 的 `padding` 的 top 原本就是 0，没有 6。
3. **聊天滚动区底部 `bottomGap()+14`：未执行。** 聊天消息区底部实际是固定 14，不依赖 `bottomGap()`；轨迹、用量、收藏页已随新值变化。

### 7.4 胶囊统一为「浅蓝底 + 深蓝字」

Theme.ets 新增 `BLUE_DEEP:string='#2F4BDB'`（改前 `BLUE_LINE` 之后一行）。

统一规则：
- 实心蓝底白字的文字胶囊、按钮 → `BLUE_SOFT` 底 + `BLUE_DEEP` 字，无边框。
- 选中态（蓝字 + 浅蓝底，或蓝字选中项）的文字与选中图标 → `BLUE_DEEP`。
- 浅蓝底上的蓝色文字胶囊（如文件数、起手胶囊、来源标签、扩展名徽章）→ `BLUE_DEEP`，与选中态保持同一种蓝。
- 白底描边的次级胶囊、红色危险文字、灰色次级文字：不改。

#### 审计表（改前行号，文件在 `entry/src/main/ets/pages/`）

**改：**

| 文件:行 | 元素 | 处理 |
|---|---|---|
| Index.ets:332 | `pill()` primary 分支（有 grow） | 实心蓝 → `BLUE_SOFT` 底、`BLUE_DEEP` 字。覆盖所有 `primary:true` 调用：同意此操作（主界面审批卡）、保存目标、按此计划开始、继续计划、保存并使用、导入、去对话里改、添加并连接 |
| Index.ets:334 | `pill()` primary 分支（无 grow） | 同上 |
| Index.ets:424 | 多选「完成」 | 实心蓝 → `BLUE_SOFT` 底、`BLUE_DEEP` 字 |
| Index.ets:692 | 文件数胶囊 `softChip` fg | `BLUE` → `BLUE_DEEP`（底 `BLUE_SOFT` 不变） |
| Index.ets:667 | 空会话起手 4 个胶囊字色 | `BLUE` → `BLUE_DEEP` |
| Index.ets:360、361 | 侧栏快捷入口（收藏 / 技能记忆 / 用量）选中图标与字 | `BLUE` → `BLUE_DEEP` |
| Index.ets:408 | 会话列表当前会话标题（选中） | `BLUE` → `BLUE_DEEP` |
| Index.ets:439、440 | 侧栏底部「设置」选中图标与字 | `BLUE` → `BLUE_DEEP` |
| Index.ets:465 | 对话 / 轨迹分段控件选中项 | `BLUE` → `BLUE_DEEP`（规格明确） |
| Index.ets:682、683 | 输入框 `/计划`、`/目标` 前缀 token | `BLUE` → `BLUE_DEEP`（选中的模式标识） |
| Index.ets:942 | 小窗策略选中胶囊 `float_strategy_*` | `BLUE` → `BLUE_DEEP` |
| Index.ets:960 | 模型配置选中胶囊 | `BLUE` → `BLUE_DEEP` |
| Index.ets:968 | 协议选中胶囊（Chat Completions / Messages） | `BLUE` → `BLUE_DEEP` |
| Index.ets:989 | 推理强度选中胶囊 `effort_*` | `BLUE` → `BLUE_DEEP` |
| Index.ets:1013、1014 | 技能 / 记忆分段选中胶囊 | `BLUE` → `BLUE_DEEP` |
| CompactChat.ets:92 | 小窗「同意」`float_approve` | 实心蓝 → `BLUE_SOFT` 底、`BLUE_DEEP` 字；id 不变 |
| StatusBar.ets:56 | 「压缩上下文」Button（`ButtonType.Capsule`，`status_compress`） | 实心蓝 → `BLUE_SOFT` 底、`BLUE_DEEP` 字；id 不变 |
| ApprovalDialog.ets:17 | 「拒绝」（系统默认蓝底白字 Button） | 白底、1px `LINE` 边、`INK2` 字，圆角 22、高 44 |
| ApprovalDialog.ets:18 | 「同意此操作」（系统默认蓝底） | `BLUE_SOFT` 底、`BLUE_DEEP` 字，圆角 22、高 44 |
| ApprovalDialog.ets:20 | 「取消任务」（系统默认蓝底） | 白底、1px `LINE` 边、`INK2` 字，圆角 22、高 44 |
| SkillMemoryPanel.ets:44 | `pill()`：查看全文、回到 vN、导入等 | primary 实心蓝 → `BLUE_SOFT` 底、`BLUE_DEEP` 字；非 primary 原 `BLUE` 字 → `BLUE_DEEP`（两者统一） |
| SkillMemoryPanel.ets:55 | 技能来源标签（自写 / 导入 / 外部）字色 | `BLUE` → `BLUE_DEEP`（浅蓝底标签） |
| Cards.ets:76 | 文件扩展名徽章字色 | `BLUE` → `BLUE_DEEP`（浅蓝底） |
| SettingsShell.ets:27 | 设置分组选中图标与字 | `BLUE` → `BLUE_DEEP` |

**不改（附原因）：**

| 文件:行 | 元素 | 原因 |
|---|---|---|
| Index.ets:697 | 主按钮圆形图标（发送 / 暂停 / 继续，白图标蓝底） | 规格例外：圆形纯图标按钮 |
| CompactChat.ets:77、79、81 | 小窗圆形主按钮 `float_pause` / `float_resume` / `float_send` | 同上 |
| Index.ets:341 | `iconButton()` 选中图标（圆形纯图标，`SELECTED` 底） | 圆形纯图标 |
| Index.ets:352、1042；SkillMemoryPanel.ets:60 | `Toggle` 的 `selectedColor(BLUE)` | 系统控件 |
| Index.ets:923 | 字号 `Slider` | 系统控件 |
| StatusBar.ets:45、101 | `Progress` 线形 / 圆环颜色 | 系统控件 |
| Index.ets:821 | 柱状图柱子 | 数据图形，不是按钮 |
| StatusBar.ets:85～87 | 运行中指示点、运行时间文字 | 状态文字，无底色 |
| CompactChat.ets:70、110；Index.ets 运行提示 | `LoadingProgress` | 系统控件 |
| CompactChat.ets:87、Index.ets:650、ApprovalDialog.ets:12 | 「需要你确认」标题 | 标题文字，无底色 |
| CompactChat.ets:94 | 小窗审批卡片 2px 蓝描边 | 卡片描边，不是胶囊 |
| CompactChat.ets:100 | 运行状态点 | 状态点 |
| Index.ets:394、396 | 会话分组标题图标 | 图标 |
| Index.ets:400、422 | 「选择本组 / 取消本组」「全选 / 清除」 | 无底色文字按钮，不是胶囊 |
| Index.ets:406 | 重命名输入框 | 输入框 |
| Index.ets:561 | 网页来源链接 | 链接 |
| Index.ets:726、727 | 标题栏「目标：…」「计划 · n/m」 | 文字链接，位于 `BLUE_SOFT` 栏内，不是胶囊 |
| Index.ets:919 | 字号档位文字 | 文字 |
| Cards.ets:84、97、113 | 「预览 / 收起」「另存为」「展开 / 收起」 | 无底色 44 高文字按钮（规格未列为胶囊） |
| Cards.ets:132、136、139 | 学会 / 询问卡片标题、推荐项描边 | 卡片与描边，不是胶囊 |
| MarkdownView.ets:14、15、27、31 | 代码块「存为文件」、正文链接、表格 | 无底色文字按钮 / 链接 |
| PlusPanel.ets:12 | 「设置 ›」文字链接（小窗） | 链接 |
| SettingsShell.ets:29 | 「‹ 设置」返回链接 | 链接 |
| TodoBar.ets:17 | 待办进度文字 | 文字 |
| CommandMenu.ets | 全文 | 无蓝色元素 |
| ExecutionFixture.ets（15 个 Button）、WebSpike.ets（3 个）、PenProbe.ets（3 个） | 开发测试页，系统默认 Button（蓝底白字） | 协调方指示保持不动，避免影响测试 id 与脚本 |
| Index.ets 中所有 `primary:false` 的 pill（拒绝、返回对话、结束目标、复制、打开会话、切换到小窗、本机重连等） | 白底 1px 描边次级胶囊 | 规格：白底描边保持 |
| 红色 / 橙色文字（删除、撤销、删除历史等） | 危险 / 次要文字 | 规格：红色危险文字保持 |

#### 7.4 grep 证据（以下行号为改后行号）

- 蓝色底色（去掉 `BLUE_SOFT` / `BLUE_LINE` / `BLUE_DEEP` 后仍含 `BLUE` 的 `backgroundColor`）：仅剩圆形图标底（Index.ets:699、CompactChat.ets:77/79/81）、柱状图（Index.ets:823）、状态点（StatusBar.ets:85、CompactChat.ets:100）以及描边 / 输入框行。
- 白色文字（`fontColor(WHITE)` / `fontColor([WHITE])`）：仅剩 4 处，全部是圆形图标按钮的白图标（CompactChat.ets:77、79、81；Index.ets:699）。
- 字面量 `#4D6BFE`、`#2F4BDB` 在 pages 中仅出现在 Theme.ets。
- 实心深蓝文字胶囊剩余：**0 处**（不计上表「不改」中列出的圆形图标与开发测试页）。

### 7.5 验证

- **编译**：`hvigorw assembleHap --no-daemon --offline`，BUILD SUCCESSFUL（17 s 982 ms）。ERROR 0。日志 `artifacts/build-08603-dev.log`。
- **离线测试**：`PYTHONUTF8=1 python scripts/verify-drawing-release.py ui0863`，53 个脚本全部 exit=0，未修改任何断言。日志 `artifacts/tests-ui0863.log`。
- **旧 id**：`grep -ho "\.id('[^']*'" pages/*.ets | sort -u` 共 37 个，与 `artifacts/ui-backup/ids-08516.txt` 逐条一致，缺失 0，新增 0。
- **符号**：本阶段未新增任何 `sys.symbol.*`（只使用既有名字）。
- **版本**：`AppScope/app.json5` versionName 0.8.6.3、versionCode 8603；`node scripts/build-secrets.cjs` 重新生成（未设置 `HARMONY_SEARCH_SECRETS`，只核对了 APP_VERSION 为 0.8.6.3）。
- **打包**：`releases/HarmonyWhale-0.8.6.3/HarmonyWhale-0.8.6.3-signed.hap`，SHA256 `56052af69c518c628e95f6add3b6f77d4c5bde811a34b64ba35393ef4da271cd`。目录原本不存在。
- **解包核对**（临时目录 scratchpad，`python -I`）：`bundleName=com.harmonyloom.selfhdcprobe`；`versionName=0.8.6.3`；`versionCode=8603`；module `entry`；abilities 仅 `ProbeAbility`；无 `extensionAbilities`；`deviceTypes=tablet`；`apiVersion compatible/target 23`（与 0.8.6.2 相同）。
- **签名核验**：`hap-sign-tool.jar verify-app` success；去掉时间戳后 39 行与 `artifacts/signature-08602.log` 逐行一致。日志 `artifacts/signature-08603.log`。`releases/HarmonyWhale-0.8.6.3/verification.json` 已写入。
- **真机 / 视觉：未验证。** 未安装，未操作平板。包括：弹窗左缘对齐、`TopLeft` 与 `offset:{y:-6}` 的方向、输入区与底栏高度、各胶囊配色、44 点击区。

### 取舍

1. 7.1 的 `offset` 方向按规格写 `y:-6`，SDK 文档只写"相对 placement 的偏移"，方向未核实。
2. 7.3 三处未执行（StatusBar 44 → 36、StatusBar 上边距 6 → 2、聊天滚动区 `bottomGap()+14`），理由见 7.3 节。
3. 侧栏与设置页底栏沿用旧间距（`legacyGap()`），防止侧栏底部贴边；输入区与轨迹 / 用量 / 收藏页底部用新值。
4. 7.4 按协调方补充把选中态文字、浅蓝底上的文字胶囊、标签、徽章也统一为 `BLUE_DEEP`，以免同屏两种蓝。系统 Toggle、Slider、Progress 与圆形图标仍用原色。
5. ApprovalDialog 三个按钮原为系统默认 Button（蓝底白字）。这里显式设置了底色、字色与圆角，三者高度统一为 44。

### 遗留

1. **搜索密钥（沿用 0.8.6.0 / 0.8.6.2 的问题，未核实）**：本次仍按规格不设置 `HARMONY_SEARCH_SECRETS` 运行 `build-secrets.cjs`。该脚本在无输入时把 `BOCHA_KEY` 写为空串，本次没有读取 `BuildSecrets.ets` 中除 APP_VERSION 外的内容，无法确认 `BOCHA_KEY` 是否为空。如需保留联网搜索密钥，需用原密钥重新生成并以新版本号重新打包。
2. **签名证书即将到期**：Development 证书有效期到 2026-10-18 00:40:55，今天 2026-10-12，约 6 天。到期后新装包的校验可能失败。
3. **开发测试页的默认蓝底白字 Button**（ExecutionFixture 15 个、WebSpike 3 个、PenProbe 3 个）未改，按协调方指示保持测试 id 不变。如果之后要统一，需要同步更新测试脚本。
4. `SkillMemoryPanel.ets` 的 `originText`、`skillStateText` 仍是阶段 2 遗留，无调用方。
5. 真机效果（见 7.5）未验证。
