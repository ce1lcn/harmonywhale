# Third-party attribution

## DeepSeek Harness

Repository: https://github.com/deepseek-ai/deepseek-harness
Commit: `5badb15009ae1756c3afe0ae0cef1faafc290ccc` (verified locally 2026-10-07).
License: MIT. Research checkout is not included in HAP.

| Original path | HarmonyWhale file | Adaptation |
|---|---|---|
| packages/client/ui-primitives/src/markdown/incremental.ts, plain-text.ts, cjkFriendlyStrong.ts; markdown/CodeBlock.tsx, CodeToolbar.tsx | agent/Markdown.ets; pages/MarkdownView.ets | Independent ArkTS block parser using a frozen prefix/two-block frontier; unfinished fences; CJK inline emphasis; plain-text projection; exact code copying and wrap control. No micromark, shiki or React code imported. |
| packages/core/system-prompt/src/index.ts; packages/core/agent-loop; packages/skill/tool-skill | agent/Conversation.ets | Fixed system prefix with host mode/rules/catalog at history tail. Original Chinese persona retained. |
| packages/compaction/compaction-basic/src/config.ts; packages/llm/llm-retry/src/index.ts; packages/llm/llm-deepseek/src/defaults.ts | agent/ExecutionPolicy.ets; agent/Engine.ets; agent/Model.ets | Threshold and tail budget formulas, bounded retry parameters, cancellable waits. Device mutation retry restrictions retained. |
| packages/guard/repeat-tool-reminder | agent/Progress.ets | 3/5 reminder stages and HarmonyWhale-specific pause at 8, including short loops. |
| packages/llm/llm-deepseek/src (Messages mapping and stream handling) | agent/MessagesProtocol.ets | Independent typed ArkTS transport mapping checked against official DeepSeek docs. No telemetry, account auth, Files upload or harness request extensions. |
| packages/llm/llm-deepseek/src/images.ts and image preparation policy | agent/Attachments.ets | Local JPEG preparation (1302px, 85/75/60, 2MiB) and sandbox references; HarmonyOS pickers/OCR are native adaptations. |

| packages/spill/spill-policy/src/retention.ts, notice.ts（头 + 省略标记 + 尾；完整结果存文件并附取回提示） | agent/Spill.ets；Engine.spillOutput / spillLayout；Files.spillText | 0.8.4 B1。保留“头尾预览 + 省略字数 + 取回提示”的做法；差别：按字符数而非估算 token，头多尾少，提示改为中文并指向 `file_read(fileId, offset, limit)`；网页正文转存为带标题与地址的可读文本；屏幕布局每步只留最新一份。带 MIT 版权头。 |
| packages/core/agent-loop/src/tool-calls.ts；packages/core/tools（executionMode） | agent/Parallel.ets；Engine.prefetchReads / runEarly | 0.8.4 B2。保留“连续的并发安全调用组成有界池、独占调用是屏障、结果按模型顺序提交、取消时给未开始的调用写合成结果”；差别：并发上限 4（DSH 默认 10），只并行本轮开头连续的只读调用，设备与写入工具之后的调用一律串行。带 MIT 版权头。 |
| packages/fs/tool-fs/src/edit.ts；packages/fs/fs-observation-policy | agent/TextFiles.ets（applyEdit）；Files.editText；FileRegistry.ets（file_edit） | 0.8.4 B3。保留字面量替换、`oldString` 非空且与 `newString` 不同、默认必须恰好出现一次、`replaceAll`、改前必读；差别：错误码与中文错误文字用大肥鱼自己的，已读记录按内容哈希保存在内存，只有 `file_read` 算已读（DSH 对本会话刚创建的文件豁免）。TextFiles.ets 带 MIT 版权头。 |
| packages/todo/tool-todo/src/index.ts, types.ts | agent/Todo.ets；agent/LocalTools.ets（todo_write）；pages/TodoBar.ets | 0.8.4 B4。保留整体替换、单个进行中、内容去空白后非空且不重复的校验与工具描述的写法；差别：字段名按任务书用 `text` / `done`，上限 20 项，待办按会话保存并显示在界面上（DSH 是会话日志投影）。Todo.ets 带 MIT 版权头；TodoBar 是原生 ArkUI 实现。 |
| packages/guard/timeout-policy/src/index.ts | agent/ExecutionPolicy.ets（toolTimeout）；Engine.guardedTool | 0.8.4 B5。保留“每个工具声明自己的时限，超时后取消并返回 TIMEOUT 错误”；差别：时限表按大肥鱼的工具重新定（网页 30 s、布局 20 s、wait_for 按参数），底层操作无法真正中断，只是不再等待。ExecutionPolicy.ets 已带 MIT 版权头。 |
| packages/compaction/compaction-basic/src/summarizer.ts（COMPACTION_INSTRUCTION、CHECKPOINT_PREAMBLE、`<compacted-summary>`）；packages/compaction/compaction-tool-result-pruner | agent/Compaction.ets；Conversation.ets（historyMessages / toolList / pruneMiddle）；Model.compactConversation；Engine.compactPrefix | 0.8.4 B6。保留“原样回放前缀 + 末尾一条压缩指令以复用前缀缓存”“已有旧摘要时合并而不是照抄”“摘要用标签包裹”“超大工具结果头尾修剪（头 / 省略标记 / 尾）”；差别：小节改成中文五节（目标、已完成、关键事实与文件、未完成与下一步、用户偏好），修剪在拼装上下文时做而不是改日志，另有回放前缀开关（`State.compactReplay`）用于与 0.8.3 旧方式对比缓存命中率。Compaction.ets 带 MIT 版权头。 |

SettingsShell and PlusPanel are native implementations of the user-approved design; no DSH UI code copied. Full license follows.

## 图片素材

以下图片由 OpenAI 的图像生成功能（GPT Image）生成，用于本项目的界面与图标。
它们**不在**根目录 `LICENSE` 的授权范围内：

| 文件 | 用途 |
| --- | --- |
| `entry/src/main/resources/base/media/avatar.jpg` | 界面中的角色头像 |
| `entry/src/main/resources/base/media/startIcon.png` | 应用启动图标 |
| `AppScope/resources/base/media/probe_icon.png` | 应用图标 |

如需在自己的项目或产品中使用这些图片，请自行确认是否具备相应权利。

```text
MIT License

Copyright (c) 2026 DeepSeek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 0.8.3 设计参考（未复制代码）

0.8.3 的 Skill 目录 whenToUse、保留 5 版本、外部来源默认停用、ask_user 选项结构、工具调用写成文字的处理、file 行号窗口等，依据 `docs/DSH-PARITY.md` 第 2.2、2.6、2.8 节与第 3 节的行为描述，用 ArkTS 自行实现：`agent/SkillStore.ets`、`agent/Memory.ets`、`agent/ToolTextGuard.ets`、`agent/LocalTools.ets`、`agent/TextFiles.ets`。
本版没有逐行复制 `research/deepseek-harness` 的源码，因此这些文件不带 DSH 版权头。若后续版本从 DSH 源码直接移植，必须补充版权声明并在本表登记具体文件与提交号。

## 0.8.4 登记说明

- 上表 0.8.4 的行是**从 DSH 源码逐段改写**的部分（读过对应源文件后用 ArkTS 重写，保留算法与语义），因此对应的 `.ets` 文件头带有 “Portions adapted from DeepSeek Harness … Copyright (c) 2026 DeepSeek. MIT” 声明，许可证全文见本文上方。
- 提交号同上（`5badb15009ae1756c3afe0ae0cef1faafc290ccc`）。研究用检出 `research/deepseek-harness` 不进 HAP。
- 没有引入 DSH 的 npm 依赖、Cordis 框架或任何请求扩展与遥测。
- 界面组件（`TodoBar`、侧边栏多选、文件卡片删除按钮）是原生 ArkUI 实现，没有复制 DSH 的 React 代码。
