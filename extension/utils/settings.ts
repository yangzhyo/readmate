export interface Settings {
  apiKey: string;
  model: string;
  /** 选中文字后是否浮现划词图标 */
  showIcon: boolean;
}

export const DEFAULT_MODEL = 'gemini-3.5-flash';

export async function loadSettings(): Promise<Settings> {
  const stored = await browser.storage.local.get(['apiKey', 'model', 'showIcon']);
  return {
    apiKey: typeof stored.apiKey === 'string' ? stored.apiKey : '',
    model:
      typeof stored.model === 'string' && stored.model.trim()
        ? stored.model.trim()
        : DEFAULT_MODEL,
    showIcon: stored.showIcon !== false,
  };
}

export async function saveSettings(settings: Settings): Promise<void> {
  await browser.storage.local.set({
    apiKey: settings.apiKey.trim(),
    model: settings.model.trim() || DEFAULT_MODEL,
    showIcon: settings.showIcon,
  });
}
