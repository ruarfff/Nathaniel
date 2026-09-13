#!/usr/bin/env node
/** Small MCP adapter for live inspection and controlled test setup. */
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema, Tool } from '@modelcontextprotocol/sdk/types.js';
import { GameClient } from './gameClient.js';

const client = new GameClient(
  process.env.GAME_SERVER_URL || 'http://localhost:8765',
  Number(process.env.GAME_SERVER_TIMEOUT || 5000),
);
const reads = {
  game_health: ['/health', 'Check whether the debug server is running.'],
  game_state: ['/state', 'Read exact game state, positions, health, Hermes mode, and tower count.'],
  game_nodes: ['/nodes', 'Read named controls and entities with scene-space bounds.'],
  game_screenshot: ['/screenshot', 'Capture the scene as a PNG.'],
  game_list_actions: ['/actions', 'Discover the current scene’s debug setup actions and parameters.'],
};
const tools: Tool[] = [
  ...Object.entries(reads).map(([name, [, description]]) => ({
    name, description, inputSchema: { type: 'object' as const, properties: {} },
  })),
  {
    name: 'game_action',
    description: 'Run a debug setup action from game_list_actions. Use computer use to test real UI input.',
    inputSchema: {
      type: 'object', required: ['name'],
      properties: { name: { type: 'string' }, params: { type: 'object', additionalProperties: { type: 'string' } } },
    },
  },
  {
    name: 'game_tap',
    description: 'Fallback pointer input by node name or scene x,y (origin bottom-left). This bypasses OS input.',
    inputSchema: {
      type: 'object',
      properties: { node: { type: 'string' }, x: { type: 'number' }, y: { type: 'number' } },
      oneOf: [{ required: ['node'] }, { required: ['x', 'y'] }],
    },
  },
  {
    name: 'game_swipe',
    description: 'Fallback tower drag in scene coordinates; elsewhere taps the endpoint. Does not simulate OS gestures or timing.',
    inputSchema: {
      type: 'object', required: ['fromX', 'fromY', 'toX', 'toY'],
      properties: {
        fromX: { type: 'number' }, fromY: { type: 'number' }, toX: { type: 'number' }, toY: { type: 'number' },
        duration: { type: 'number', default: 0.3, minimum: 0 },
      },
    },
  },
];
const server = new Server({ name: 'nathaniel-game', version: '1.0.0' }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));
server.setRequestHandler(CallToolRequestSchema, async ({ params: { name, arguments: args = {} } }) => {
  try {
    let path: string;
    let body: unknown;
    if (Object.hasOwn(reads, name)) {
      [path] = reads[name as keyof typeof reads];
    } else if (name === 'game_action') {
      if (typeof args.name !== 'string' || !args.name ||
          (args.params !== undefined && (args.params === null || typeof args.params !== 'object' ||
            Array.isArray(args.params) || Object.values(args.params).some(value => typeof value !== 'string')))) {
        throw new Error('Expected an action name and optional string parameters');
      }
      path = '/action';
      body = { name: args.name, params: args.params };
    } else if (name === 'game_tap') {
      path = '/tap';
      if (typeof args.node === 'string' && args.node && args.x === undefined && args.y === undefined) {
        body = { node: args.node };
      } else if (args.node === undefined && Number.isFinite(args.x) && Number.isFinite(args.y)) {
        body = { x: args.x, y: args.y };
      } else throw new Error('Supply either a node name or finite x,y coordinates');
    } else if (name === 'game_swipe') {
      const { fromX, fromY, toX, toY, duration = 0.3 } = args;
      if (![fromX, fromY, toX, toY, duration].every(Number.isFinite) || (duration as number) < 0) {
        throw new Error('Expected finite drag coordinates and a nonnegative duration');
      }
      path = '/swipe';
      body = { fromX, fromY, toX, toY, duration };
    } else throw new Error(`Unknown tool: ${name}`);
    const result = await client.request(path, body);
    if (result.success === false) throw new Error(result.error || result.message || 'Game command failed');
    if (name === 'game_screenshot') {
      return { content: [{ type: 'image' as const, data: result.data, mimeType: 'image/png' }] };
    }
    return { content: [{ type: 'text' as const, text: JSON.stringify(result) }] };
  } catch (error) {
    return { isError: true, content: [{ type: 'text' as const, text: error instanceof Error ? error.message : String(error) }] };
  }
});
await server.connect(new StdioServerTransport());
