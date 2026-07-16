# Translator — 英文阅读即时理解

帮助中文母语读者在阅读英文时即时理解卡住的单词或句子：选中 → 触发 → 原地浮出**语境化中文解释**，关掉立即回到阅读。设计原则：**打断最小、回到阅读最快**；查询不留任何记录。

同一产品有两个载体，共享同一套领域语言（见 [CONTEXT.md](./CONTEXT.md)）与设计决策（见 [docs/adr/](./docs/adr/)）：

| 载体 | 覆盖场景 | 触发 |
|------|----------|------|
| [`extension/`](./extension/) — Chrome 插件 | 网页阅读 | 划词图标或 `⌥T` |
| [`macos/`](./macos/) — macOS 常驻工具 | 终端（Claude Code 等）与桌面应用 | 全局 `⌥T`（Chrome 前台时自动让位给插件） |

构建与安装说明见各载体目录内的 README。两个载体各自保存一份 Gemini API key（插件存 `chrome.storage.local`，macOS 端存钥匙串），互不同步。
