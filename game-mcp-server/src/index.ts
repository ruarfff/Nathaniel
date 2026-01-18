#!/usr/bin/env node
/**
 * MCP Server for Nathaniel game testing.
 *
 * This server exposes the GameCommandServer's HTTP API as MCP tools,
 * allowing LLM agents to control and test the game programmatically.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import { GameClient } from './gameClient.js';

// Configuration
const GAME_SERVER_URL = process.env.GAME_SERVER_URL || 'http://localhost:8765';
const GAME_SERVER_TIMEOUT = parseInt(process.env.GAME_SERVER_TIMEOUT || '5000', 10);

// Initialize game client
const gameClient = new GameClient(GAME_SERVER_URL, GAME_SERVER_TIMEOUT);

// Tool definitions
const tools: Tool[] = [
  {
    name: 'game_health',
    description: 'Check if the game command server is running and healthy. Returns true if the game is ready to accept commands.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_state',
    description: 'Get structured game state as JSON. Returns: scene name, score, lives, resources, elapsedTime, gameStatus, isPaused, playerPosition, hermesPosition, enemyCount. Use for PROGRAMMATIC CHECKS like verifying score increased or player moved. For human-readable understanding, use game_describe instead.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_get_state',
    description: 'Alias for game_state. Get structured game state as JSON.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_nodes',
    description: 'Get interactive elements with precise frame coordinates. Returns array of {name, type, frame: {x, y, width, height}, interactive, properties}. Use BEFORE game_tap to find button coordinates, or use game_tap with node parameter directly. Coordinates use scene space with origin at bottom-left.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_get_nodes',
    description: 'Alias for game_nodes. Get interactive elements with coordinates.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_screenshot',
    description: 'Capture a screenshot of the current game screen. Returns base64-encoded PNG data. Use this to visually verify the game state.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_screenshot_annotated',
    description: 'Capture an annotated screenshot with bounding boxes around all interactive nodes. Color-coded: green=players, red=enemies, cyan=towers, yellow=UI, orange=projectiles. Very useful for understanding what elements are on screen and where they are located.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_describe',
    description: 'Get human-readable scene summary. RECOMMENDED AS FIRST CALL to understand what is on screen. Returns: summary, playerStatus, threats, ui, suggestions for what to do next. Best for general understanding of game state. For programmatic checks, use game_get_state instead.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_list_actions',
    description: 'List all available actions for the current scene, grouped by category. Returns action names, descriptions, and required parameters. Use this to discover what actions you can execute with game_action. Actions vary by scene (MainMenuScene, LevelSelectScene, GameScene, etc).',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_tap',
    description: 'Tap in the game. Two modes: (1) By coordinates: game_tap(x, y) - tap at specific scene coordinates. (2) By node name: game_tap(node: "startButton") - finds the node and taps its center automatically. Mode 2 is recommended as it requires fewer steps.',
    inputSchema: {
      type: 'object',
      properties: {
        x: {
          type: 'number',
          description: 'X coordinate to tap (in scene coordinates). Required if node not specified.',
        },
        y: {
          type: 'number',
          description: 'Y coordinate to tap (in scene coordinates). Required if node not specified.',
        },
        node: {
          type: 'string',
          description: 'Name of the node to tap (e.g., "startButton", "level_1"). The node center will be tapped automatically.',
        },
      },
      required: [],
    },
  },
  {
    name: 'game_swipe',
    description: 'Perform a swipe gesture from one point to another. Useful for scrolling or drag gestures.',
    inputSchema: {
      type: 'object',
      properties: {
        fromX: {
          type: 'number',
          description: 'Starting X coordinate',
        },
        fromY: {
          type: 'number',
          description: 'Starting Y coordinate',
        },
        toX: {
          type: 'number',
          description: 'Ending X coordinate',
        },
        toY: {
          type: 'number',
          description: 'Ending Y coordinate',
        },
        duration: {
          type: 'number',
          description: 'Duration of the swipe in seconds (default: 0.3)',
        },
      },
      required: ['fromX', 'fromY', 'toX', 'toY'],
    },
  },
  {
    name: 'game_action',
    description: `Execute a named game action. Available actions depend on the current scene.

**MainMenuScene:** startGame, continueGame, loadGame, options, credits, hasSaves, getSaveSlots

**LevelSelectScene:** level_1, level_2, level_3, level_4, level_5, back

**OptionsScene:** back, toggleSound, toggleMusic

**CreditsScene:** back

**GameScene - Character:** selectNathaniel, selectHermes, toggleCharacter, moveNathaniel (x, y), targetEnemy (index)

**GameScene - Hermes:** setHermesMode (mode: following|independent), toggleHermesFollow, getHermesMode

**GameScene - Pause:** pause, resume, isPaused, showPauseMenu, hidePauseMenu, pauseMenuIsVisible, pauseMenuTapResume, pauseMenuTapSettings, pauseMenuTapSaveGame, pauseMenuTapExitToMenu, pauseMenuConfirmExit, pauseMenuCancelExit, exitToMenu (skipConfirm: true)

**GameScene - Settings:** openSettings, closeSettings, settingsMenuIsVisible, toggleSoundEffects, toggleMusic, getSoundEffectsEnabled, getMusicEnabled, getCurrentSettings, setSoundEffects (enabled), setMusic (enabled), settingsMenuTapBack

**GameScene - Save:** saveGame (slot: 1-3), getSaveSlots, hasSaves, showSaveSlotSelector, hideSaveSlotSelector, saveSlotSelectorIsVisible, deleteSaveSlot (slot), deleteAllSaves

**GameScene - Debug:** spawnEnemy (type: grunt|soldier|boss, x, y), killAllEnemies, healPlayer, addResources (amount), getCombatState, getNathanielTarget, getHermesTarget, getHermesCombatState, getTowerTargets, waitForCombat

**GameScene - Building:** toggleBuildMenu, buildMenuIsVisible, buildTower (type: gun|laser|heal, x, y), sellTower (index), getTowerCount`,
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Name of the action to execute',
        },
        params: {
          type: 'object',
          additionalProperties: { type: 'string' },
          description: 'Optional parameters for the action',
        },
        wait_for_scene: {
          type: 'string',
          description: 'Optional: Wait for this scene after executing action (e.g., "LevelSelectScene", "GameScene"). Combines action + wait into atomic operation.',
        },
        timeout: {
          type: 'number',
          description: 'Timeout in seconds when using wait_for_scene (default: 10)',
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'game_wait_for_scene',
    description: 'Wait for a scene change using long-polling. Use this after triggering a scene transition (e.g., startGame, level_1) to wait until the new scene is loaded. Returns immediately if already at the expected scene. Useful for reliable scene navigation without manual delays.',
    inputSchema: {
      type: 'object',
      properties: {
        scene: {
          type: 'string',
          description: 'Scene name to wait for (e.g., "GameScene", "MainMenuScene", "LevelSelectScene"). If not specified, waits for any scene change.',
        },
        timeout: {
          type: 'number',
          description: 'Timeout in seconds (default: 10). Request will return after this time even if scene has not changed.',
        },
      },
      required: [],
    },
  },
  {
    name: 'game_debug_overlay',
    description: 'Toggle, show, or hide the debug overlay that highlights interactive UI elements with color-coded bounding boxes. Useful for visually identifying clickable elements during testing.',
    inputSchema: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: ['show', 'hide', 'toggle'],
          description: 'Action to perform on the debug overlay',
        },
      },
      required: ['action'],
    },
  },
  {
    name: 'game_visual_diff',
    description: 'Compare two images and highlight differences. Returns match status, diff percentage, and optionally a diff image showing changed pixels in red.',
    inputSchema: {
      type: 'object',
      properties: {
        image1: {
          type: 'string',
          description: 'First image as base64-encoded PNG',
        },
        image2: {
          type: 'string',
          description: 'Second image as base64-encoded PNG',
        },
        threshold: {
          type: 'number',
          description: 'Percentage threshold for considering images as matching (0-100, default: 1.0)',
        },
        generateDiffImage: {
          type: 'boolean',
          description: 'Whether to generate a visual diff image (default: true)',
        },
      },
      required: ['image1', 'image2'],
    },
  },
  {
    name: 'game_diff_baseline',
    description: 'Compare current screenshot against a saved baseline image. Use for visual regression testing.',
    inputSchema: {
      type: 'object',
      properties: {
        baseline: {
          type: 'string',
          description: 'Name of the baseline to compare against',
        },
        threshold: {
          type: 'number',
          description: 'Percentage threshold for considering images as matching (0-100, default: 1.0)',
        },
        generateDiffImage: {
          type: 'boolean',
          description: 'Whether to generate a visual diff image (default: true)',
        },
      },
      required: ['baseline'],
    },
  },
  {
    name: 'game_list_baselines',
    description: 'List all saved baseline images for visual regression testing.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_save_baseline',
    description: 'Save the current screenshot as a baseline for visual regression testing.',
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Unique name for the baseline (e.g., "MainMenu_Default", "GameScene_Level1")',
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'game_delete_baseline',
    description: 'Delete a saved baseline image.',
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Name of the baseline to delete',
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'game_start_level',
    description: `Navigate to a specific level from any scene. This convenience tool handles all the multi-step navigation automatically:
- From MainMenuScene: startGame → LevelSelectScene → level_N → GameScene
- From LevelSelectScene: level_N → GameScene
- From GameScene: exitToMenu → MainMenuScene → startGame → LevelSelectScene → level_N → GameScene
- From OptionsScene/CreditsScene: back → MainMenuScene → startGame → LevelSelectScene → level_N → GameScene

Returns the navigation steps taken and total time. Much simpler than manual multi-step navigation.`,
    inputSchema: {
      type: 'object',
      properties: {
        level: {
          type: 'number',
          description: 'Level number to start (1-5)',
          minimum: 1,
          maximum: 5,
        },
      },
      required: ['level'],
    },
  },
  {
    name: 'game_goto_menu',
    description: `Navigate to the main menu from any scene. This convenience tool handles exit confirmation and back navigation automatically:
- From MainMenuScene: Already there, returns immediately
- From LevelSelectScene: back → MainMenuScene
- From GameScene: exitToMenu (with skipConfirm) → MainMenuScene
- From OptionsScene/CreditsScene: back → MainMenuScene

Returns the navigation steps taken and total time.`,
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
];

// Create MCP server
const server = new Server(
  {
    name: 'nathaniel-game-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Handle list_tools request
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'game_health': {
        const healthy = await gameClient.healthCheck();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({ healthy, serverUrl: GAME_SERVER_URL }, null, 2),
            },
          ],
        };
      }

      case 'game_state':
      case 'game_get_state': {
        const state = await gameClient.getState();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(state, null, 2),
            },
          ],
        };
      }

      case 'game_nodes':
      case 'game_get_nodes': {
        const nodes = await gameClient.getNodes();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(nodes, null, 2),
            },
          ],
        };
      }

      case 'game_screenshot': {
        const screenshot = await gameClient.screenshot();
        if (screenshot.success) {
          return {
            content: [
              {
                type: 'image',
                data: screenshot.data,
                mimeType: 'image/png',
              },
            ],
          };
        } else {
          return {
            content: [
              {
                type: 'text',
                text: 'Failed to capture screenshot',
              },
            ],
            isError: true,
          };
        }
      }

      case 'game_screenshot_annotated': {
        const screenshot = await gameClient.annotatedScreenshot();
        if (screenshot.success) {
          return {
            content: [
              {
                type: 'image',
                data: screenshot.data,
                mimeType: 'image/png',
              },
              {
                type: 'text',
                text: `Annotated screenshot captured. ${screenshot.nodeCount} interactive nodes highlighted.`,
              },
            ],
          };
        } else {
          return {
            content: [
              {
                type: 'text',
                text: 'Failed to capture annotated screenshot',
              },
            ],
            isError: true,
          };
        }
      }

      case 'game_describe': {
        const description = await gameClient.describe();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(description, null, 2),
            },
          ],
        };
      }

      case 'game_list_actions': {
        const actions = await gameClient.listActions();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(actions, null, 2),
            },
          ],
        };
      }

      case 'game_tap': {
        const tapArgs = args as { x?: number; y?: number; node?: string };

        // Mode 2: Tap by node name
        if (tapArgs.node) {
          const result = await gameClient.tapNode(tapArgs.node);
          return {
            content: [
              {
                type: 'text',
                text: JSON.stringify(result, null, 2),
              },
            ],
          };
        }

        // Mode 1: Tap by coordinates
        if (tapArgs.x === undefined || tapArgs.y === undefined) {
          return {
            content: [
              {
                type: 'text',
                text: 'Error: Either node name or x,y coordinates are required',
              },
            ],
            isError: true,
          };
        }

        const result = await gameClient.tap(tapArgs.x, tapArgs.y);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_swipe': {
        const swipeArgs = args as {
          fromX: number;
          fromY: number;
          toX: number;
          toY: number;
          duration?: number;
        };
        const result = await gameClient.swipe(
          swipeArgs.fromX,
          swipeArgs.fromY,
          swipeArgs.toX,
          swipeArgs.toY,
          swipeArgs.duration
        );
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_action': {
        const actionArgs = args as {
          name: string;
          params?: Record<string, string>;
          wait_for_scene?: string;
          timeout?: number;
        };

        // Execute the action
        const result = await gameClient.action(actionArgs.name, actionArgs.params);

        // If wait_for_scene specified, wait for scene transition
        if (actionArgs.wait_for_scene && result.success) {
          const timeout = actionArgs.timeout ?? 10;
          const sceneResult = await gameClient.waitForScene(timeout, actionArgs.wait_for_scene);

          return {
            content: [
              {
                type: 'text',
                text: JSON.stringify(
                  {
                    action: result,
                    sceneTransition: sceneResult,
                    success: !sceneResult.timedOut,
                  },
                  null,
                  2
                ),
              },
            ],
          };
        }

        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_wait_for_scene': {
        const waitArgs = args as { scene?: string; timeout?: number };
        const result = await gameClient.waitForScene(waitArgs.timeout ?? 10, waitArgs.scene);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_debug_overlay': {
        const overlayArgs = args as { action: 'show' | 'hide' | 'toggle' };
        const result = await gameClient.debugOverlay(overlayArgs.action);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_visual_diff': {
        const diffArgs = args as {
          image1: string;
          image2: string;
          threshold?: number;
          generateDiffImage?: boolean;
        };
        const result = await gameClient.visualDiff(
          diffArgs.image1,
          diffArgs.image2,
          diffArgs.threshold ?? 1.0,
          diffArgs.generateDiffImage ?? true
        );
        const content: Array<{ type: string; text?: string; data?: string; mimeType?: string }> = [
          {
            type: 'text',
            text: JSON.stringify({ ...result, diffImage: result.diffImage ? '[base64 image]' : null }, null, 2),
          },
        ];
        if (result.diffImage) {
          content.push({
            type: 'image',
            data: result.diffImage,
            mimeType: 'image/png',
          });
        }
        return { content };
      }

      case 'game_diff_baseline': {
        const baselineArgs = args as {
          baseline: string;
          threshold?: number;
          generateDiffImage?: boolean;
        };
        const result = await gameClient.diffAgainstBaseline(
          baselineArgs.baseline,
          baselineArgs.threshold ?? 1.0,
          baselineArgs.generateDiffImage ?? true
        );
        const content: Array<{ type: string; text?: string; data?: string; mimeType?: string }> = [
          {
            type: 'text',
            text: JSON.stringify({ ...result, diffImage: result.diffImage ? '[base64 image]' : null }, null, 2),
          },
        ];
        if (result.diffImage) {
          content.push({
            type: 'image',
            data: result.diffImage,
            mimeType: 'image/png',
          });
        }
        return { content };
      }

      case 'game_list_baselines': {
        const result = await gameClient.listBaselines();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_save_baseline': {
        const saveArgs = args as { name: string };
        const result = await gameClient.saveBaseline(saveArgs.name);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_delete_baseline': {
        const deleteArgs = args as { name: string };
        const result = await gameClient.deleteBaseline(deleteArgs.name);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_start_level': {
        const levelArgs = args as { level: number };
        const result = await gameClient.startLevel(levelArgs.level);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'game_goto_menu': {
        const result = await gameClient.gotoMenu();
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      default:
        return {
          content: [
            {
              type: 'text',
              text: `Unknown tool: ${name}`,
            },
          ],
          isError: true,
        };
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${errorMessage}`,
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  console.error('[nathaniel-mcp-server] Starting server...');
  console.error(`[nathaniel-mcp-server] Game server URL: ${GAME_SERVER_URL}`);

  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error('[nathaniel-mcp-server] Server running');
}

main().catch((error) => {
  console.error('[nathaniel-mcp-server] Fatal error:', error);
  process.exit(1);
});
