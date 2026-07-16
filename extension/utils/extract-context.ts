/**
 * 提取「上下文」：选区所在段落 + 前后各一段，总长上限 3000 字符。
 * 相邻段取靠近选区的一端（前段取尾、后段取头）。
 */

const TOTAL_CAP = 3000;
const CURRENT_CAP = 1200;
const SIBLING_CAP = 900;

export function extractContext(selection: Selection): string {
  const range = selection.getRangeAt(0);
  const block = closestBlock(range.startContainer) ?? document.body;

  const current = normalize(textOf(block));
  const prev = normalize(textOf(siblingBlock(block, 'previous')));
  const next = normalize(textOf(siblingBlock(block, 'next')));

  const parts: string[] = [];
  if (prev) parts.push(clipEnd(prev, SIBLING_CAP));
  parts.push(clipAround(current, normalize(selection.toString()), CURRENT_CAP));
  if (next) parts.push(clipStart(next, SIBLING_CAP));

  return parts.join('\n\n').slice(0, TOTAL_CAP);
}

/** 沿祖先链向上找第一个块级渲染的元素 */
function closestBlock(node: Node): Element | null {
  let el: Element | null = node instanceof Element ? node : node.parentElement;
  while (el && el !== document.body) {
    const display = getComputedStyle(el).display;
    if (display === 'block' || display === 'list-item' || display === 'table-cell') {
      return el;
    }
    el = el.parentElement;
  }
  return el;
}

/** 找相邻的、有文字内容的兄弟块；本层没有则上一层再找一次 */
function siblingBlock(block: Element, direction: 'previous' | 'next'): Element | null {
  for (let base: Element | null = block; base && base !== document.body; base = base.parentElement) {
    let el =
      direction === 'previous' ? base.previousElementSibling : base.nextElementSibling;
    while (el) {
      if (normalize(textOf(el))) return el;
      el = direction === 'previous' ? el.previousElementSibling : el.nextElementSibling;
    }
  }
  return null;
}

function textOf(el: Element | null): string {
  if (!el) return '';
  return (el as HTMLElement).innerText ?? el.textContent ?? '';
}

function normalize(text: string): string {
  return text.replace(/\s+/g, ' ').trim();
}

function clipStart(text: string, cap: number): string {
  return text.length <= cap ? text : `${text.slice(0, cap)}…`;
}

function clipEnd(text: string, cap: number): string {
  return text.length <= cap ? text : `…${text.slice(-cap)}`;
}

/** 段落超长时，以选区为中心截窗口，保证选区一定在上下文里 */
function clipAround(text: string, selectionText: string, cap: number): string {
  if (text.length <= cap) return text;
  const at = selectionText ? text.indexOf(selectionText) : -1;
  if (at === -1) return clipStart(text, cap);
  const half = Math.max(0, Math.floor((cap - selectionText.length) / 2));
  const start = Math.max(0, at - half);
  const end = Math.min(text.length, at + selectionText.length + half);
  const prefix = start > 0 ? '…' : '';
  const suffix = end < text.length ? '…' : '';
  return `${prefix}${text.slice(start, end)}${suffix}`;
}
