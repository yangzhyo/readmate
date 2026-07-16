import type { Browser } from 'wxt/browser';
import { streamExplanation } from '../utils/gemini';
import { loadSettings } from '../utils/settings';
import {
  EXPLAIN_PORT,
  type ExplainRequest,
  type PortResponse,
  type RuntimeMessage,
} from '../utils/messages';

export default defineBackground(() => {
  browser.action.onClicked.addListener(() => {
    void browser.runtime.openOptionsPage();
  });

  browser.runtime.onMessage.addListener((message) => {
    if ((message as RuntimeMessage)?.type === 'open-options') {
      void browser.runtime.openOptionsPage();
    }
  });

  browser.runtime.onConnect.addListener((port) => {
    if (port.name !== EXPLAIN_PORT) return;
    port.onMessage.addListener((raw) => {
      const msg = raw as ExplainRequest;
      if (msg?.type !== 'explain') return;
      void handleExplain(port, msg);
    });
  });
});

async function handleExplain(port: Browser.runtime.Port, msg: ExplainRequest): Promise<void> {
  const abort = new AbortController();
  let disconnected = false;
  port.onDisconnect.addListener(() => {
    disconnected = true;
    abort.abort();
  });
  const post = (response: PortResponse) => {
    if (disconnected) return;
    try {
      port.postMessage(response);
    } catch {
      disconnected = true;
    }
  };

  try {
    const settings = await loadSettings();
    if (!settings.apiKey) {
      post({ type: 'error', code: 'missing-key', message: '还没有配置 Gemini API key' });
      return;
    }
    for await (const chunk of streamExplanation(settings, msg.selection, msg.context, abort.signal)) {
      post({ type: 'chunk', text: chunk });
    }
    post({ type: 'done' });
  } catch (error) {
    if (abort.signal.aborted) return;
    post({
      type: 'error',
      code: 'request-failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
}
