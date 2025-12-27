/**
 * HTTP client for communicating with the GameCommandServer running in the game.
 */

export interface GameState {
  scene: string;
  score: number;
  lives: number;
  resources: number;
  elapsedTime: number;
  gameStatus: string;
  playerPosition: { x: number; y: number } | null;
  hermesPosition: { x: number; y: number } | null;
  enemyCount: number;
}

export interface NodeInfo {
  name: string;
  type: string;
  frame: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  interactive: boolean;
  properties?: Record<string, string>;
}

export interface CommandResponse {
  success: boolean;
  message?: string;
  gameState?: GameState;
  error?: string;
}

export interface ScreenshotResponse {
  success: boolean;
  format: string;
  data: string;  // base64 encoded
}

export class GameClient {
  private baseUrl: string;
  private timeout: number;

  constructor(baseUrl: string = 'http://localhost:8765', timeout: number = 5000) {
    this.baseUrl = baseUrl;
    this.timeout = timeout;
  }

  /**
   * Check if the game server is running and healthy
   */
  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.fetch<{ status: string }>('/health', { method: 'GET' });
      return response.status === 'ok';
    } catch {
      return false;
    }
  }

  /**
   * Get the current game state
   */
  async getState(): Promise<GameState> {
    return this.fetch<GameState>('/state', { method: 'GET' });
  }

  /**
   * Get all interactive nodes in the current scene
   */
  async getNodes(): Promise<NodeInfo[]> {
    return this.fetch<NodeInfo[]>('/nodes', { method: 'GET' });
  }

  /**
   * Capture a screenshot of the current scene
   */
  async screenshot(): Promise<ScreenshotResponse> {
    return this.fetch<ScreenshotResponse>('/screenshot', { method: 'GET' });
  }

  /**
   * Inject a tap at the given screen coordinates
   */
  async tap(x: number, y: number): Promise<CommandResponse> {
    return this.fetch<CommandResponse>('/tap', {
      method: 'POST',
      body: JSON.stringify({ x, y }),
    });
  }

  /**
   * Inject a swipe gesture
   */
  async swipe(
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    duration: number = 0.3
  ): Promise<CommandResponse> {
    return this.fetch<CommandResponse>('/swipe', {
      method: 'POST',
      body: JSON.stringify({ fromX, fromY, toX, toY, duration }),
    });
  }

  /**
   * Execute a named game action
   */
  async action(name: string, params?: Record<string, string>): Promise<CommandResponse> {
    return this.fetch<CommandResponse>('/action', {
      method: 'POST',
      body: JSON.stringify({ name, params }),
    });
  }

  /**
   * Internal fetch helper with timeout
   */
  private async fetch<T = unknown>(path: string, options: RequestInit): Promise<T> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(`${this.baseUrl}${path}`, {
        ...options,
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`HTTP ${response.status}: ${errorText}`);
      }

      return await response.json();
    } catch (error) {
      clearTimeout(timeoutId);
      if (error instanceof Error && error.name === 'AbortError') {
        throw new Error(`Request timeout after ${this.timeout}ms`);
      }
      throw error;
    }
  }
}
