/** content → background，经 Port 发送 */
export interface ExplainRequest {
  type: 'explain';
  selection: string;
  context: string;
}

/** background → content，经 Port 逐条推送 */
export type PortResponse =
  | { type: 'chunk'; text: string }
  | { type: 'done' }
  | { type: 'error'; code: 'missing-key' | 'request-failed'; message: string };

/** 一次性 runtime 消息 */
export type RuntimeMessage = { type: 'trigger' } | { type: 'open-options' };

export const EXPLAIN_PORT = 'explain';
