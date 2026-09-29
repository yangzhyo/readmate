// 扩展自己的界面（划词图标、解释卡）上的鼠标事件不让页面收到。
//
// 页面常在 document 上监听点击，点在抽屉、弹层、下拉菜单外面就把它关掉。图标和卡片挂在
// <html> 下，在页面看来总是点在外面：在抽屉里划词、点图标，抽屉就被关了。
// 在宿主元素上 stopPropagation 拦不住 document 捕获阶段的监听，只能在 window 捕获阶段
// 抢在页面之前截停。截停后界面里的按钮也收不到，由这里在影子树里补发一份。

const ISOLATED_EVENTS = ['pointerdown', 'mousedown', 'touchstart', 'pointerup', 'mouseup', 'touchend', 'click'];
/** 界面里的监听只用到这几种，只补发它们 */
const REPLAYED_EVENTS = new Set(['mousedown', 'mouseup', 'click']);

const hosts = new WeakSet<EventTarget>();

/** 须在页面脚本之前调用：同在 window 捕获阶段的监听按注册先后执行 */
export function installEventIsolation(): void {
  for (const type of ISOLATED_EVENTS) window.addEventListener(type, onEvent, true);
}

export function isolateFromPage(host: HTMLElement): void {
  hosts.add(host);
}

function onEvent(event: Event): void {
  const path = event.composedPath();
  if (!path.some((node) => hosts.has(node))) return;
  event.stopImmediatePropagation();
  if (!(event instanceof MouseEvent) || !REPLAYED_EVENTS.has(event.type)) return;

  // 副本默认 composed: false，传不出影子树，页面收不到
  const copy = new MouseEvent(event.type, {
    bubbles: true,
    cancelable: true,
    detail: event.detail,
    button: event.button,
    buttons: event.buttons,
    clientX: event.clientX,
    clientY: event.clientY,
    ctrlKey: event.ctrlKey,
    shiftKey: event.shiftKey,
    altKey: event.altKey,
    metaKey: event.metaKey,
  });
  path[0].dispatchEvent(copy);
  // 图标靠阻止 mousedown 默认行为保住选区，要落到原事件上才生效
  if (copy.defaultPrevented) event.preventDefault();
}
