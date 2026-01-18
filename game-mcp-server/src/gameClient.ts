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
  nodeCount?: number;  // Only present for annotated screenshots
}

export interface DescribeResponse {
  summary: string;
  playerStatus: string;
  threats: string;
  ui?: string;
  score?: number;
  lives?: number;
  resources?: number;
  elapsedTime?: number;
  suggestions?: string[];
  enemyCount: number;
  nodeCount: number;
}

export interface ActionInfo {
  name: string;
  description: string;
  params?: string;
}

export interface ActionsResponse {
  scene: string;
  actions: Record<string, ActionInfo[]>;
}

export interface SceneChangeEvent {
  previousScene: string | null;
  currentScene: string;
  timestamp: number;
  timedOut: boolean;
}

export interface DebugOverlayResponse {
  success?: boolean;
  visible: boolean;
}

export interface VisualDiffResult {
  match: boolean;
  diffPercentage: number;
  diffPixelCount: number;
  totalPixels: number;
  threshold: number;
  diffImage?: string;  // base64 encoded
  error?: string;
}

export interface BaselineListResponse {
  baselines: string[];
  count: number;
}

export interface BaselineResponse {
  success: boolean;
  name: string;
  message: string;
}

export interface NavigationStep {
  action: string;
  scene?: string;
  success: boolean;
}

export interface NavigationResult {
  success: boolean;
  steps: NavigationStep[];
  totalTime: number;
  error?: string;
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
   * Capture a screenshot with annotated bounding boxes around interactive nodes
   */
  async annotatedScreenshot(): Promise<ScreenshotResponse> {
    return this.fetch<ScreenshotResponse>('/screenshot/annotated', { method: 'GET' });
  }

  /**
   * Get a semantic description of the current scene for agent understanding
   */
  async describe(): Promise<DescribeResponse> {
    return this.fetch<DescribeResponse>('/describe', { method: 'GET' });
  }

  /**
   * List all available actions for the current scene, grouped by category
   */
  async listActions(): Promise<ActionsResponse> {
    return this.fetch<ActionsResponse>('/actions', { method: 'GET' });
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
   * Inject a tap at a node by name (finds node and taps its center)
   */
  async tapNode(nodeName: string): Promise<CommandResponse> {
    return this.fetch<CommandResponse>('/tap', {
      method: 'POST',
      body: JSON.stringify({ node: nodeName }),
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

  // Debug Overlay

  /**
   * Toggle, show, or hide the debug overlay
   */
  async debugOverlay(action: 'show' | 'hide' | 'toggle'): Promise<DebugOverlayResponse> {
    return this.fetch<DebugOverlayResponse>('/debug/overlay', {
      method: 'POST',
      body: JSON.stringify({ action }),
    });
  }

  /**
   * Get the current debug overlay state
   */
  async getDebugOverlayState(): Promise<DebugOverlayResponse> {
    return this.fetch<DebugOverlayResponse>('/debug/overlay', { method: 'GET' });
  }

  // Visual Diff

  /**
   * Compare two images and return diff result
   */
  async visualDiff(
    image1: string,
    image2: string,
    threshold: number = 1.0,
    generateDiffImage: boolean = true
  ): Promise<VisualDiffResult> {
    return this.fetch<VisualDiffResult>('/diff', {
      method: 'POST',
      body: JSON.stringify({ image1, image2, threshold, generateDiffImage }),
    });
  }

  /**
   * Compare current screenshot against a saved baseline
   */
  async diffAgainstBaseline(
    baselineName: string,
    threshold: number = 1.0,
    generateDiffImage: boolean = true,
    currentImage?: string
  ): Promise<VisualDiffResult> {
    return this.fetch<VisualDiffResult>('/diff/baseline', {
      method: 'POST',
      body: JSON.stringify({
        baseline: baselineName,
        threshold,
        generateDiffImage,
        ...(currentImage && { image: currentImage }),
      }),
    });
  }

  // Baselines

  /**
   * List all saved baselines
   */
  async listBaselines(): Promise<BaselineListResponse> {
    return this.fetch<BaselineListResponse>('/baselines', { method: 'GET' });
  }

  /**
   * Save current screenshot or provided image as a baseline
   */
  async saveBaseline(name: string, image?: string): Promise<BaselineResponse> {
    return this.fetch<BaselineResponse>('/baselines', {
      method: 'POST',
      body: JSON.stringify({ name, ...(image && { image }) }),
    });
  }

  /**
   * Delete a baseline
   */
  async deleteBaseline(name: string): Promise<BaselineResponse> {
    return this.fetch<BaselineResponse>(`/baselines/${encodeURIComponent(name)}`, {
      method: 'DELETE',
    });
  }

  /**
   * Wait for a scene change with long-polling.
   * If expectedScene is specified, waits until that specific scene is active.
   * If not specified, waits for any scene change.
   * @param timeout Timeout in seconds (default 10)
   * @param expectedScene Optional scene name to wait for
   */
  async waitForScene(timeout: number = 10, expectedScene?: string): Promise<SceneChangeEvent> {
    // Build query string
    const params = new URLSearchParams();
    params.set('timeout', timeout.toString());
    if (expectedScene) {
      params.set('scene', expectedScene);
    }

    // Use a longer timeout for this request since it's long-polling
    const requestTimeout = (timeout + 2) * 1000;
    return this.fetchWithTimeout<SceneChangeEvent>(
      `/wait_for_scene?${params.toString()}`,
      { method: 'GET' },
      requestTimeout
    );
  }

  // High-level navigation convenience methods

  /**
   * Navigate to a specific level from any scene.
   * Handles multi-step navigation automatically.
   */
  async startLevel(level: number): Promise<NavigationResult> {
    const steps: NavigationStep[] = [];
    const startTime = Date.now();

    try {
      // Get current state
      const state = await this.getState();
      const currentScene = state.scene;
      steps.push({ action: 'getState', scene: currentScene, success: true });

      // Route based on current scene
      if (currentScene === 'GameScene') {
        // Exit to menu first
        const exitResult = await this.action('exitToMenu', { skipConfirm: 'true' });
        steps.push({ action: 'exitToMenu', success: exitResult.success });
        if (!exitResult.success) {
          return this.navigationResult(false, steps, startTime, 'Failed to exit game');
        }
        const waitMenu = await this.waitForScene(10, 'MainMenuScene');
        steps.push({ action: 'waitForScene', scene: 'MainMenuScene', success: !waitMenu.timedOut });
        if (waitMenu.timedOut) {
          return this.navigationResult(false, steps, startTime, 'Timeout waiting for MainMenuScene');
        }
      } else if (currentScene === 'OptionsScene' || currentScene === 'CreditsScene') {
        // Go back to main menu
        const backResult = await this.action('back');
        steps.push({ action: 'back', success: backResult.success });
        const waitMenu = await this.waitForScene(10, 'MainMenuScene');
        steps.push({ action: 'waitForScene', scene: 'MainMenuScene', success: !waitMenu.timedOut });
        if (waitMenu.timedOut) {
          return this.navigationResult(false, steps, startTime, 'Timeout waiting for MainMenuScene');
        }
      }

      // Now we should be at MainMenuScene or LevelSelectScene
      const currentState = await this.getState();
      if (currentState.scene === 'MainMenuScene') {
        // Go to level select
        const startResult = await this.action('startGame');
        steps.push({ action: 'startGame', success: startResult.success });
        if (!startResult.success) {
          return this.navigationResult(false, steps, startTime, 'Failed to start game');
        }
        const waitLevelSelect = await this.waitForScene(10, 'LevelSelectScene');
        steps.push({ action: 'waitForScene', scene: 'LevelSelectScene', success: !waitLevelSelect.timedOut });
        if (waitLevelSelect.timedOut) {
          return this.navigationResult(false, steps, startTime, 'Timeout waiting for LevelSelectScene');
        }
      }

      // Now at LevelSelectScene - select the level
      const levelAction = `level_${level}`;
      const levelResult = await this.action(levelAction);
      steps.push({ action: levelAction, success: levelResult.success });
      if (!levelResult.success) {
        return this.navigationResult(false, steps, startTime, `Failed to select ${levelAction}`);
      }

      // Wait for GameScene
      const waitGame = await this.waitForScene(10, 'GameScene');
      steps.push({ action: 'waitForScene', scene: 'GameScene', success: !waitGame.timedOut });
      if (waitGame.timedOut) {
        return this.navigationResult(false, steps, startTime, 'Timeout waiting for GameScene');
      }

      return this.navigationResult(true, steps, startTime);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return this.navigationResult(false, steps, startTime, message);
    }
  }

  /**
   * Navigate to the main menu from any scene.
   * Handles exit confirmation and back navigation automatically.
   */
  async gotoMenu(): Promise<NavigationResult> {
    const steps: NavigationStep[] = [];
    const startTime = Date.now();

    try {
      // Get current state
      const state = await this.getState();
      const currentScene = state.scene;
      steps.push({ action: 'getState', scene: currentScene, success: true });

      if (currentScene === 'MainMenuScene') {
        // Already at menu
        return this.navigationResult(true, steps, startTime);
      }

      if (currentScene === 'GameScene') {
        // Exit game with skip confirmation
        const exitResult = await this.action('exitToMenu', { skipConfirm: 'true' });
        steps.push({ action: 'exitToMenu', success: exitResult.success });
        if (!exitResult.success) {
          return this.navigationResult(false, steps, startTime, 'Failed to exit game');
        }
      } else if (currentScene === 'LevelSelectScene' || currentScene === 'OptionsScene' || currentScene === 'CreditsScene') {
        // Use back action
        const backResult = await this.action('back');
        steps.push({ action: 'back', success: backResult.success });
        if (!backResult.success) {
          return this.navigationResult(false, steps, startTime, 'Failed to go back');
        }
      } else {
        return this.navigationResult(false, steps, startTime, `Unknown scene: ${currentScene}`);
      }

      // Wait for MainMenuScene
      const waitMenu = await this.waitForScene(10, 'MainMenuScene');
      steps.push({ action: 'waitForScene', scene: 'MainMenuScene', success: !waitMenu.timedOut });
      if (waitMenu.timedOut) {
        return this.navigationResult(false, steps, startTime, 'Timeout waiting for MainMenuScene');
      }

      return this.navigationResult(true, steps, startTime);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return this.navigationResult(false, steps, startTime, message);
    }
  }

  /**
   * Helper to build navigation result
   */
  private navigationResult(
    success: boolean,
    steps: NavigationStep[],
    startTime: number,
    error?: string
  ): NavigationResult {
    return {
      success,
      steps,
      totalTime: Date.now() - startTime,
      ...(error && { error }),
    };
  }

  /**
   * Internal fetch helper with default timeout
   */
  private async fetch<T = unknown>(path: string, options: RequestInit): Promise<T> {
    return this.fetchWithTimeout<T>(path, options, this.timeout);
  }

  /**
   * Internal fetch helper with custom timeout
   */
  private async fetchWithTimeout<T = unknown>(path: string, options: RequestInit, timeout: number): Promise<T> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

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
        throw new Error(`Request timeout after ${timeout}ms`);
      }
      throw error;
    }
  }
}
