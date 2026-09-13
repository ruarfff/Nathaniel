/** HTTP transport for the game's DEBUG-only command server. */
export class GameClient {
  constructor(private baseUrl: string, private timeout = 5000) {}

  async request(path: string, body?: unknown): Promise<any> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeout);
    try {
      const response = await fetch(`${this.baseUrl}${path}`, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`Game server returned HTTP ${response.status}: ${await response.text()}`);
      return await response.json();
    } finally {
      clearTimeout(timer);
    }
  }
}
