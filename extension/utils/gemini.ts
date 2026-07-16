import type { Settings } from './settings';
import { SYSTEM_PROMPT, buildUserPrompt } from './prompt';

const API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

/**
 * 调用 Gemini streamGenerateContent（SSE），逐段产出解释文本。
 * 由 background 调用——host_permissions 已覆盖该域名，不受 CORS 限制。
 */
export async function* streamExplanation(
  settings: Settings,
  selection: string,
  context: string,
  signal: AbortSignal,
): AsyncGenerator<string> {
  const url = `${API_BASE}/${encodeURIComponent(settings.model)}:streamGenerateContent?alt=sse`;
  const res = await fetch(url, {
    method: 'POST',
    signal,
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': settings.apiKey,
    },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: 'user', parts: [{ text: buildUserPrompt(selection, context) }] }],
      generationConfig: { maxOutputTokens: 4096 },
    }),
  });

  if (!res.ok || !res.body) {
    const detail = await res.text().catch(() => '');
    throw new Error(`Gemini API ${res.status}：${summarizeApiError(detail)}`);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let newline: number;
    while ((newline = buffer.indexOf('\n')) !== -1) {
      const line = buffer.slice(0, newline).trim();
      buffer = buffer.slice(newline + 1);
      const text = parseSseLine(line);
      if (text) yield text;
    }
  }
  const tail = parseSseLine(buffer.trim());
  if (tail) yield tail;
}

function parseSseLine(line: string): string {
  if (!line.startsWith('data:')) return '';
  const data = line.slice(5).trim();
  if (!data || data === '[DONE]') return '';
  let payload: unknown;
  try {
    payload = JSON.parse(data);
  } catch {
    return '';
  }
  const parts = (payload as any)?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return '';
  return parts
    .map((p: unknown) => (typeof (p as any)?.text === 'string' ? (p as any).text : ''))
    .join('');
}

function summarizeApiError(body: string): string {
  try {
    const parsed = JSON.parse(body);
    const message = parsed?.error?.message;
    if (typeof message === 'string') return message.slice(0, 200);
  } catch {
    // 非 JSON 响应，原样截断
  }
  return body.slice(0, 200) || '未知错误';
}
