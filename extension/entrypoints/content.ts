import { extractContext } from '../utils/extract-context';
import {
  EXPLAIN_PORT,
  type ExplainRequest,
  type PortResponse,
  type RuntimeMessage,
} from '../utils/messages';

export default defineContentScript({
  matches: ['<all_urls>'],
  main() {
    document.addEventListener('mouseup', onMouseUp);
    document.addEventListener('selectionchange', () => {
      const selection = window.getSelection();
      if (!selection || selection.isCollapsed) icon?.hide();
    });
  },
});

const CARD_WIDTH = 400;
const CARD_ESTIMATED_HEIGHT = 220;

let card: Card | null = null;
let icon: TriggerIcon | null = null;

function onTrigger(): void {
  icon?.hide();
  const selection = window.getSelection();
  const selectionText = selection?.toString().replace(/\s+/g, ' ').trim() ?? '';
  if (!selection || selection.rangeCount === 0 || !selectionText) {
    showToast('先选中要解释的文字');
    return;
  }

  const rect = selection.getRangeAt(0).getBoundingClientRect();
  const context = extractContext(selection);

  card?.close();
  card = new Card(rect, () => {
    card = null;
  });
  card.request({ type: 'explain', selection: selectionText, context });
}

function onMouseUp(event: MouseEvent): void {
  const path = event.composedPath();
  if (icon && path.includes(icon.host)) return;
  if (card && path.includes(card.host)) return;

  // 等浏览器完成本次选区更新（双击选词等）再判断
  setTimeout(() => {
    const selection = window.getSelection();
    const text = selection?.toString().trim() ?? '';
    if (!selection || selection.isCollapsed || !text) {
      icon?.hide();
      return;
    }
    // 输入框/可编辑区域内不打扰
    const active = document.activeElement;
    if (
      active instanceof HTMLInputElement ||
      active instanceof HTMLTextAreaElement ||
      (active instanceof HTMLElement && active.isContentEditable)
    ) {
      return;
    }
    icon ??= new TriggerIcon(onTrigger);
    icon.show(event.clientX, event.clientY);
  }, 0);
}

/** 选中文字后浮现在光标附近的小按钮，点击即触发解释 */
class TriggerIcon {
  readonly host: HTMLDivElement;

  constructor(onActivate: () => void) {
    this.host = document.createElement('div');
    const shadow = this.host.attachShadow({ mode: 'open' });
    shadow.innerHTML = `<style>${ICON_CSS}</style><button class="icon" title="解释选中内容">译</button>`;
    const button = shadow.querySelector('button')!;
    // 阻止 mousedown 默认行为，避免点击图标时选区被清除
    button.addEventListener('mousedown', (event) => event.preventDefault());
    button.addEventListener('click', () => onActivate());
    this.host.style.cssText = 'position:absolute;z-index:2147483647;display:none;';
    document.documentElement.append(this.host);
  }

  show(clientX: number, clientY: number): void {
    const x = Math.min(clientX + window.scrollX + 6, window.scrollX + window.innerWidth - 40);
    const y = clientY + window.scrollY + 14;
    this.host.style.left = `${x}px`;
    this.host.style.top = `${y}px`;
    this.host.style.display = 'block';
  }

  hide(): void {
    this.host.style.display = 'none';
  }
}

class Card {
  readonly host: HTMLDivElement;
  private bodyEl: HTMLDivElement;
  private markdown = '';
  private port: ReturnType<typeof browser.runtime.connect> | null = null;
  private lastRequest: ExplainRequest | null = null;
  private settled = false;

  constructor(
    anchor: DOMRect,
    private onClose: () => void,
  ) {
    this.host = document.createElement('div');
    const shadow = this.host.attachShadow({ mode: 'open' });
    shadow.innerHTML = `<style>${CARD_CSS}</style><div class="card" part="card"><div class="body"></div></div>`;
    this.bodyEl = shadow.querySelector('.body')!;
    this.position(anchor);
    document.documentElement.append(this.host);
    this.showStatus('思考中…');

    document.addEventListener('keydown', this.onKeydown, true);
    document.addEventListener('pointerdown', this.onPointerDown, true);
  }

  request(req: ExplainRequest): void {
    this.lastRequest = req;
    this.markdown = '';
    this.settled = false;
    this.showStatus('思考中…');

    const port = browser.runtime.connect({ name: EXPLAIN_PORT });
    this.port = port;
    port.onMessage.addListener((raw) => {
      const msg = raw as PortResponse;
      if (msg.type === 'chunk') {
        this.markdown += msg.text;
        this.bodyEl.innerHTML = renderMarkdown(this.markdown);
      } else if (msg.type === 'done') {
        this.settled = true;
        if (!this.markdown) this.showError('引擎没有返回内容', true);
      } else if (msg.type === 'error') {
        this.settled = true;
        if (msg.code === 'missing-key') {
          this.showError('还没有配置 Gemini API key', false, true);
        } else {
          this.showError(msg.message, true);
        }
      }
    });
    port.onDisconnect.addListener(() => {
      if (!this.settled) this.showError('连接中断', true);
    });
    port.postMessage(req);
  }

  close(): void {
    this.port?.disconnect();
    this.port = null;
    document.removeEventListener('keydown', this.onKeydown, true);
    document.removeEventListener('pointerdown', this.onPointerDown, true);
    this.host.remove();
    this.onClose();
  }

  private onKeydown = (event: KeyboardEvent) => {
    if (event.key === 'Escape') {
      event.stopPropagation();
      this.close();
    }
  };

  private onPointerDown = (event: PointerEvent) => {
    if (!event.composedPath().includes(this.host)) this.close();
  };

  private position(anchor: DOMRect): void {
    const x = clamp(
      anchor.left + window.scrollX,
      window.scrollX + 8,
      window.scrollX + Math.max(8, window.innerWidth - CARD_WIDTH - 8),
    );
    const placeAbove =
      anchor.bottom + CARD_ESTIMATED_HEIGHT > window.innerHeight && anchor.top > CARD_ESTIMATED_HEIGHT;
    this.host.style.cssText = `position:absolute;z-index:2147483647;left:${x}px;top:${
      placeAbove ? anchor.top + window.scrollY - 8 : anchor.bottom + window.scrollY + 8
    }px;${placeAbove ? 'transform:translateY(-100%);' : ''}`;
  }

  private showStatus(text: string): void {
    this.bodyEl.innerHTML = `<span class="status">${escapeHtml(text)}</span>`;
  }

  private showError(message: string, retryable: boolean, needsKey = false): void {
    this.bodyEl.innerHTML = `<span class="error">${escapeHtml(message)}</span>`;
    if (needsKey) {
      const btn = this.actionButton('打开设置', () => {
        void browser.runtime.sendMessage({ type: 'open-options' } satisfies RuntimeMessage);
        this.close();
      });
      this.bodyEl.append(btn);
    } else if (retryable && this.lastRequest) {
      const btn = this.actionButton('重试', () => {
        this.port?.disconnect();
        this.request(this.lastRequest!);
      });
      this.bodyEl.append(btn);
    }
  }

  private actionButton(label: string, onClick: () => void): HTMLButtonElement {
    const btn = document.createElement('button');
    btn.className = 'action';
    btn.textContent = label;
    btn.addEventListener('click', onClick);
    return btn;
  }
}

function showToast(text: string): void {
  const toast = document.createElement('div');
  const shadow = toast.attachShadow({ mode: 'open' });
  shadow.innerHTML = `<style>${TOAST_CSS}</style><div class="toast">${escapeHtml(text)}</div>`;
  document.documentElement.append(toast);
  setTimeout(() => toast.remove(), 1800);
}

function renderMarkdown(md: string): string {
  return escapeHtml(md)
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\n/g, '<br>');
}

function escapeHtml(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

const CARD_CSS = `
:host { all: initial; }
.card {
  box-sizing: border-box;
  width: min(${CARD_WIDTH}px, calc(100vw - 32px));
  max-height: 50vh;
  overflow-y: auto;
  background: #ffffff;
  color: #1f2328;
  border: 1px solid #d0d7de;
  border-radius: 10px;
  box-shadow: 0 8px 24px rgba(31, 35, 40, 0.15);
  padding: 12px 14px;
  font: 14px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
  user-select: text;
  -webkit-user-select: text;
}
.body { word-break: break-word; }
.body strong { color: #0550ae; }
.body code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.92em;
  background: rgba(175, 184, 193, 0.2);
  border-radius: 4px;
  padding: 0.1em 0.3em;
}
.status { color: #656d76; }
.status::after {
  content: '';
  display: inline-block;
  width: 1em;
  animation: dots 1.2s steps(4, end) infinite;
  overflow: hidden;
  vertical-align: bottom;
}
@keyframes dots { 0% { width: 0; } 100% { width: 1.2em; } }
.error { color: #cf222e; }
.action {
  display: inline-block;
  margin-left: 10px;
  padding: 2px 10px;
  font: inherit;
  font-size: 13px;
  color: #1f2328;
  background: #f6f8fa;
  border: 1px solid #d0d7de;
  border-radius: 6px;
  cursor: pointer;
}
.action:hover { background: #eef1f4; }
@media (prefers-color-scheme: dark) {
  .card {
    background: #1c2128;
    color: #e6edf3;
    border-color: #444c56;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  }
  .body strong { color: #79b8ff; }
  .body code { background: rgba(110, 118, 129, 0.4); }
  .status { color: #909dab; }
  .error { color: #ff7b72; }
  .action { color: #e6edf3; background: #2d333b; border-color: #444c56; }
  .action:hover { background: #373e47; }
}
`;

const ICON_CSS = `
:host { all: initial; }
.icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  padding: 0;
  border: none;
  border-radius: 50%;
  background: #0969da;
  color: #ffffff;
  font: 600 13px/1 -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
  box-shadow: 0 2px 8px rgba(31, 35, 40, 0.3);
  cursor: pointer;
  transition: transform 0.1s ease;
}
.icon:hover { transform: scale(1.12); }
`;

const TOAST_CSS = `
:host { all: initial; }
.toast {
  position: fixed;
  z-index: 2147483647;
  left: 50%;
  bottom: 48px;
  transform: translateX(-50%);
  background: rgba(31, 35, 40, 0.92);
  color: #ffffff;
  padding: 8px 16px;
  border-radius: 8px;
  font: 13px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", sans-serif;
}
`;
