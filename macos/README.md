# Translator for macOS — 终端与桌面应用里的英文阅读即时理解

菜单栏常驻工具（图标「译」）。在**任意应用**（终端里的 Claude Code、桌面版 ChatGPT 等）选中英文，按 `⌥T`，选区旁浮出语境化中文解释；`Esc` 或点卡外关闭，立即回到阅读。Chrome 前台时 `⌥T` 自动让位给浏览器插件。

## 构建与安装

```sh
./make-app.sh        # swift build + 组装 Translator.app（ad-hoc 签名）
mv Translator.app /Applications/
open /Applications/Translator.app
```

首次运行会引导授予**辅助功能**权限（系统设置 → 隐私与安全性 → 辅助功能）——取词和全局快捷键都依赖它。授权后无需重启应用，工具会自动重试。之后点菜单栏「译」→「设置…」填入 [Google AI Studio](https://aistudio.google.com/apikey) 的 Gemini API key。

- API key 存本机钥匙串；模型默认 `gemini-3.5-flash`，可在设置里改
- 默认注册开机自启，可在菜单栏关闭
- 停用/启用快捷键：菜单栏「译」→「启用（⌥T）」

## 行为说明

- **取词**：优先走 Accessibility（无副作用）；不支持的应用退回「模拟 `⌘C` → 读剪贴板 → 恢复原内容」，恢复写入带 `org.nspasteboard.TransientType` 标记（守规范的剪贴板历史工具会忽略）。
- **上下文**：尽力而为——AX 能读到焦点元素全文时，附带选区两侧的窗口帮助消歧；读不到（多数终端）只发选区本身，此时单词解释按最常见义并点明歧义。取舍见 [ADR-0001](../docs/adr/0001-macos-context-best-effort.md)。
- **Esc**：仅在解释卡可见时被本工具消费，不会漏给底下的应用（在 Claude Code 里 `Esc` 是打断键）；卡不在时完全不干预。
- **隐私**：触发时选中文字（及可获得的上下文）发送给 Google Gemini API，除此之外不发送任何数据；查询不留任何记录。
