# Translator — 英文阅读即时理解

选中看不懂的英文，点一下浮现的「译」图标，**语境化中文解释**原地浮出——关掉立刻回到阅读。

![Chrome MV3](https://img.shields.io/badge/Chrome-Manifest%20V3-4285F4?logo=googlechrome&logoColor=white)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?logo=typescript&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![Gemini](https://img.shields.io/badge/Engine-Gemini%20Flash-8E75B2)

为中文母语读者打造的英文阅读伴侣。设计原则只有一条：**打断最小、回到阅读最快**——它不是词典，不是翻译软件，也不是语言学习系统。

## 它给什么

不是词典义项的罗列，而是选中内容**在当前上下文里的意思**：

| 选中 | 解释卡内容 |
|------|-----------|
| 单词 | IPA 音标 + 它在这句话里的意思（加粗）+ 必要的本义补充；习语、术语会点明 |
| 短语 | 语境含义 + 本义补充 |
| 句子 | 整句中文翻译 + 一两句难点拆解（习语、语法、指代） |

解释由 Gemini Flash 实时流式生成，各载体客户端直连、无自建后端，**查询不留任何记录**。

## 两个载体

同一产品覆盖两类阅读环境，共享同一套领域语言（[CONTEXT.md](./CONTEXT.md)）与设计决策（[docs/adr/](./docs/adr/)）：

| 载体 | 覆盖场景 | 触发 |
|------|----------|------|
| [`extension/`](./extension/) — Chrome 插件 | 网页阅读 | 选中后点击浮现的划词图标 |
| [`macos/`](./macos/) — 菜单栏常驻工具 | 终端（Claude Code 等）与任意桌面应用 | 选中后点击浮现的划词图标（Chrome 前台不浮现，由插件负责）；菜单栏「解释当前选中」兜底 |

两个载体都不提供快捷键（`Esc` 关卡除外），原因见 [ADR-0002](./docs/adr/0002-icon-only-trigger.md)。

## 快速开始

两个载体都需要一个 [Google AI Studio](https://aistudio.google.com/apikey) 的 Gemini API key（免费额度即可）。key 各自保存在本机（插件存 `chrome.storage.local`，macOS 端存钥匙串），互不同步、不上传。

### Chrome 插件

```sh
cd extension
pnpm install
pnpm build        # 产物在 .output/chrome-mv3/
```

Chrome 打开 `chrome://extensions` → 开启「开发者模式」→「加载已解压的扩展程序」→ 选 `.output/chrome-mv3/`，然后点击工具栏插件图标填入 API key。详见 [extension/README.md](./extension/README.md)。

### macOS

```sh
cd macos
./make-app.sh     # swift build + 组装 Translator.app
mv Translator.app /Applications/
open /Applications/Translator.app
```

首次运行按引导授予**辅助功能**权限（取词与手势检测依赖它），再从菜单栏「译」→「设置…」填入 API key。详见 [macos/README.md](./macos/README.md)。

## 工作原理

```
选中文字 ──▶ 划词图标 ──▶ 捕获选区 + 提取上下文 ──▶ Gemini Flash（流式） ──▶ 解释卡（Esc / 点外关闭）
```

- **上下文提取**：解释质量的关键。插件取选区所在段落及前后各一段（上限 3000 字符）；macOS 端尽力而为——焦点元素通过 Accessibility 暴露全文时附带选区两侧窗口，读不到（多数终端）只发选区本身，由提示词内建降级规则兜底（[ADR-0001](./docs/adr/0001-macos-context-best-effort.md)）。
- **macOS 取词**：优先走 Accessibility（无副作用）；不支持的应用退回「模拟 `⌘C` → 读剪贴板 → 恢复原内容」；连 `⌘C` 都拿不到时（如选中即复制的 TUI）以 15 秒内的剪贴板变化兜底，解释卡顶部会显示实际取到的选区便于核对。
- **模型可换**：默认 `gemini-3.5-flash`，两端设置里都可改（更快更省可切 `flash-lite` 系列）。

## 隐私

- 触发时，仅选中文字及可获得的上下文发送到 Google Gemini API，除此之外不发送任何数据
- 查询不留任何记录，用完即弃；无自建后端，无遥测
- API key 只存本机，不同步、不上传

## 仓库结构

```
extension/   Chrome 插件（WXT + TypeScript，Manifest V3）
macos/       macOS 菜单栏工具（Swift Package，AppKit，macOS 13+）
docs/adr/    架构决策记录
CONTEXT.md   领域语言：载体、选区、上下文、解释卡、触发、引擎……
```
