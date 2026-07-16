export interface Settings {
  apiKey: string;
  model: string;
}

export const DEFAULT_MODEL = 'gemini-3.5-flash';

export async function loadSettings(): Promise<Settings> {
  const stored = await browser.storage.local.get(['apiKey', 'model']);
  return {
    apiKey: typeof stored.apiKey === 'string' ? stored.apiKey : '',
    model:
      typeof stored.model === 'string' && stored.model.trim()
        ? stored.model.trim()
        : DEFAULT_MODEL,
  };
}

export async function saveSettings(settings: Settings): Promise<void> {
  await browser.storage.local.set({
    apiKey: settings.apiKey.trim(),
    model: settings.model.trim() || DEFAULT_MODEL,
  });
}
