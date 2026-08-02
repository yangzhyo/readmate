// 发音：选区的读音，「怎么读」的听觉通道。由载体自身合成，不经引擎——
// 因而不产生任何查询，也与解释的成败无关。
// 与 macos/Sources/Translator/Pronunciation.swift 是同一职责的两端实现，判定规则须一致。

/** 只有单词才发音，与音标同条件：去掉首尾标点后不含空白，且是拉丁字母词 */
export function speakableWord(selection: string): string | null {
  const word = selection.trim().replace(/^[^\p{L}]+|[^\p{L}]+$/gu, '');
  if (!word || /\s/.test(word) || !/[A-Za-z]/.test(word)) return null;
  return word;
}

/**
 * 只给 lang 不给 voice 时，Chrome 按语音表首个匹配项挑——而 macOS 的英语语音表
 * 按字母序打头的是 Albert、Bad News、Bahh 这些趣味音。系统语言非英语时（本产品的
 * 读者几乎都是）更没有「默认英语语音」兜底，必然挑中它们，听起来不像人在说话。
 */
const PREFERRED_VOICES = [
  'Samantha', // macOS 美音基准；macOS 载体的 AVSpeechSynthesizer 选的也是它，两端同声
  'Alex',
  'Microsoft Aria',
  'Microsoft Zira',
  'Microsoft David',
];

/** 让出一拍去排队的那次 speak，关卡片时要能撤掉 */
let pendingSpeak: number | null = null;

/** 语音表首次可能为空，提前触发一次填充，等真正点喇叭时已就绪 */
export function warmUpVoices(): void {
  window.speechSynthesis?.getVoices();
}

function pickVoice(): SpeechSynthesisVoice | null {
  // 只用本地语音：远程语音（如 Google US English）会把读者查的词发给第三方
  const local = window.speechSynthesis.getVoices().filter((v) => v.localService && v.lang === 'en-US');
  for (const name of PREFERRED_VOICES) {
    // 前缀匹配：Chrome 会给语音名加后缀（macOS 的「Flo (英语（美国）)」、
    // Windows 的「Microsoft David Desktop - English (United States)」），精确匹配匹不中
    const hit = local.find((v) => v.name === name || v.name.startsWith(`${name} `));
    if (hit) return hit;
  }
  // 都没有就退回系统标记的默认英语语音；再没有则交给浏览器，不盲选首个
  return local.find((v) => v.default) ?? null;
}

/** 正在播时再点 = 打断重播，不叠音 */
export function speak(word: string): void {
  const synth = window.speechSynthesis;
  if (!synth) return;
  clearPending();

  const utterance = new SpeechSynthesisUtterance(word);
  utterance.lang = 'en-US'; // 与卡片上的美式 IPA 同口音
  const voice = pickVoice();
  if (voice) utterance.voice = voice;

  if (!synth.speaking && !synth.pending) {
    synth.speak(utterance);
    return;
  }
  // cancel() 是异步的：同一 tick 里紧接着 speak()，新 utterance 会被这次 cancel
  // 一起扫掉，只拿到 error: canceled 且没有声音。让出一拍再排队。
  synth.cancel();
  pendingSpeak = window.setTimeout(() => {
    pendingSpeak = null;
    synth.speak(utterance);
  }, 0);
}

/** 关卡片即收声；排队中的那一拍也要撤，否则卡片没了声音才响 */
export function stopSpeaking(): void {
  clearPending();
  window.speechSynthesis?.cancel();
}

function clearPending(): void {
  if (pendingSpeak === null) return;
  clearTimeout(pendingSpeak);
  pendingSpeak = null;
}
