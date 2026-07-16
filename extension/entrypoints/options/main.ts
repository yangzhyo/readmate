import { DEFAULT_MODEL, loadSettings, saveSettings } from '../../utils/settings';

const apiKeyInput = document.querySelector<HTMLInputElement>('#apiKey')!;
const modelInput = document.querySelector<HTMLInputElement>('#model')!;
const showIconInput = document.querySelector<HTMLInputElement>('#showIcon')!;
const saveButton = document.querySelector<HTMLButtonElement>('#save')!;
const statusEl = document.querySelector<HTMLSpanElement>('#status')!;

void (async () => {
  const settings = await loadSettings();
  apiKeyInput.value = settings.apiKey;
  modelInput.value = settings.model;
  showIconInput.checked = settings.showIcon;
})();

saveButton.addEventListener('click', async () => {
  await saveSettings({
    apiKey: apiKeyInput.value,
    model: modelInput.value || DEFAULT_MODEL,
    showIcon: showIconInput.checked,
  });
  statusEl.textContent = '已保存';
  setTimeout(() => {
    statusEl.textContent = '';
  }, 1500);
});
