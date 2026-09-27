// 应用图标里的像素鹦鹉，划词图标用它。
// 网格与配色须与 macos/make-icon.swift、macos/Sources/Readmate/ParrotSprite.swift 保持一致。

// D=深色描边 G=绿羽 R=红呆毛 O=橙喙 W=白眼圈 K=瞳孔 L=浅色腹部 P=腮红 .=透明
const GRID = [
  '.........DDD........',
  '........DRRRD.......',
  '...DDDDDDRRRDDDDD...',
  '..DGGGGGGGRGGGGGGD..',
  '.DGGGGGGGGGGGGGGGGD.',
  '.DGGWWWWGGGGWWWWGGD.',
  '.DGGWKKWGGGGWKKWGGD.',
  '.DGGWKKWGGGGWKKWGGD.',
  '.DGGWWWWGGGGWWWWGGD.',
  '.DGGGGGGOOOOGGGGGGD.',
  '.DGGGGGGGOOGGGGGGGD.',
  '.DGGPGGGGGGGGGGPGGD.',
  '.DGGGLLLLLLLLLLGGGD.',
  '..DGGLLLLLLLLLLGGD..',
  '...DGGLLLLLLLLGGD...',
  '....DDGGLLLLGGDD....',
  '......DDDDDDDD......',
];

const PALETTE: Record<string, string> = {
  D: '#21262b',
  G: '#3dba59',
  R: '#e84f40',
  O: '#f59e1c',
  W: '#ffffff',
  K: '#1a1c21',
  L: '#c7ed9e',
  P: '#faa8b8',
};

/**
 * 每格 1 CSS 像素的 SVG：Retina 下每格正好 2 个物理像素，crispEdges 保证边缘不发虚。
 * 须按原尺寸显示，缩放到非整数倍会糊。
 */
export function parrotSvg(): string {
  const paths = new Map<string, string>();
  GRID.forEach((row, y) => {
    [...row].forEach((cell, x) => {
      const color = PALETTE[cell];
      if (color) paths.set(color, `${paths.get(color) ?? ''}M${x} ${y}h1v1h-1z`);
    });
  });
  const body = [...paths].map(([color, d]) => `<path fill="${color}" d="${d}"/>`).join('');
  const width = GRID[0].length;
  const height = GRID.length;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" shape-rendering="crispEdges" aria-hidden="true">${body}</svg>`;
}
