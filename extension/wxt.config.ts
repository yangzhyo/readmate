import { defineConfig } from 'wxt';

export default defineConfig({
  manifest: {
    name: 'Translator — 英文阅读即时理解',
    description: '选中看不懂的英文单词或句子，按快捷键获得语境化中文解释',
    permissions: ['storage'],
    host_permissions: ['https://generativelanguage.googleapis.com/*'],
    commands: {
      'explain-selection': {
        suggested_key: { default: 'Alt+T' },
        description: '解释当前选中的文字',
      },
    },
    action: {
      default_title: '打开 Translator 设置',
    },
  },
});
