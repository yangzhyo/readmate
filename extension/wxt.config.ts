import { defineConfig } from 'wxt';

export default defineConfig({
  manifest: {
    name: 'Translator — 英文阅读即时理解',
    description: '选中看不懂的英文单词或句子，点击浮现的图标获得语境化中文解释',
    permissions: ['storage'],
    host_permissions: ['https://generativelanguage.googleapis.com/*'],
    action: {
      default_title: '打开 Translator 设置',
    },
  },
});
