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
  ToolSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { GameClient } from './gameClient.js';

// Configuration
const GAME_SERVER_URL = process.env.GAME_SERVER_URL || 'http://localhost:8765';
const GAME_SERVER_TIMEOUT = parseInt(process.env.GAME_SERVER_TIMEOUT || '5000', 10);

// Initialize game client
const gameClient = new GameClient(GAME_SERVER_URL, GAME_SERVER_TIMEOUT);

// Tool definitions
const tools: ToolSchema[] = [
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
    name: 'game_get_state',
    description: 'Get the current game state including scene name, score, lives, resources, player positions, and enemy count. Use this to understand what is happening in the game.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
  {
    name: 'game_get_nodes',
    description: 'Get all interactive nodes in the current scene with their names, types, positions (frame coordinates), and properties. Use this to find buttons, characters, enemies, and other interactive elements before tapping them.',
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
    name: 'game_tap',
    description: 'Tap at specific screen coordinates in the game. Use game_get_nodes first to find the correct coordinates for buttons and interactive elements.',
    inputSchema: {
      type: 'object',
      properties: {
        x: {
          type: 'number',
          description: 'X coordinate to tap (in scene coordinates)',
        },
        y: {
          type: 'number',
          description: 'Y coordinate to tap (in scene coordinates)',
        },
      },
      required: ['x', 'y'],
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
    description: 'Execute a named game action. Available actions depend on the current scene. Common actions: selectNathaniel, selectHermes, moveNathaniel (params: x, y), targetEnemy (params: index), startGame, options, credits, back.',
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
      },
      required: ['name'],
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

      case 'game_tap': {
        const tapArgs = args as { x: number; y: number };
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
        const actionArgs = args as { name: string; params?: Record<string, string> };
        const result = await gameClient.action(actionArgs.name, actionArgs.params);
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
