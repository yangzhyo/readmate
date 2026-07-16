# Translator — 英文阅读即时理解

选中看不懂的英文单词或句子，点击浮现的**划词图标**，在原地弹出**语境化中文解释**：

- 选中**单词** → IPA 音标 + 它在这句话里的意思（加粗）+ 必要的本义补充，习语/术语会点明
- 选中**短语** → 语境含义 + 本义补充
- 选中**句子** → 整句翻译 + 一两句难点拆解（习语、语法、指代）

设计原则：打断最小、回到阅读最快。查询不留任何记录。领域词汇见 [CONTEXT.md](../CONTEXT.md)。

## 构建

```sh
pnpm install
pnpm build        # 产物在 .output/chrome-mv3/
pnpm dev          # 开发模式（热重载）
```

## 安装（加载未打包插件）

1. Chrome 打开 `chrome://extensions`，右上角开启「开发者模式」
2. 「加载已解压的扩展程序」→ 选择 `.output/chrome-mv3/` 目录
3. 点击工具栏中的插件图标打开设置，填入 [Google AI Studio](https://aistudio.google.com/apikey) 的 Gemini API key

## 使用

在任意网页选中一段英文，点击光标旁浮现的「译」图标。解释卡出现在选区旁，流式输出；`Esc` 或点击卡外关闭。

- 换模型：设置页可改（默认 `gemini-3.5-flash`，更快更省可切 `flash-lite` 系列）

## 架构一览

```
entrypoints/
├── background.ts    # 经 Port 流式调用 Gemini（host_permissions 直连，无 CORS）
├── content.ts       # 选区捕获、Shadow DOM 解释卡（流式渲染 / Esc / 点外关闭 / 重试）
└── options/         # 设置页：API key + 模型，存 chrome.storage.local（仅本机）
utils/
├── extract-context.ts  # 上下文提取：所在段 + 前后各一段，上限 3000 字符
├── gemini.ts           # streamGenerateContent SSE 客户端
├── prompt.ts           # 系统提示词（语境化解释规则）
├── settings.ts         # 设置读写
└── messages.ts         # content ↔ background 消息类型
```

隐私说明：触发时，选中文字及其前后段落会发送到 Google Gemini API；API key 只保存在本机 `chrome.storage.local`，不同步、不上传。
