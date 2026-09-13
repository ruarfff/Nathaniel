// Run against an explicitly started, isolated, headless Godot debug process.
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { Client } from '../../game-mcp-server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from '../../game-mcp-server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';

const endpoint = process.argv[2] || 'http://127.0.0.1:18766';
const client = new Client({ name: 'godot-integration', version: '1.0.0' });
let checks = 0;
const check = (value, message) => { checks++; assert.ok(value, message); };
const call = async (name, args) => {
  const result = await client.callTool({ name, arguments: args });
  check(!result.isError, `${name}: ${result.content?.[0]?.text}`);
  return JSON.parse(result.content[0].text);
};
const action = (name, params = {}) => call('game_action', { name, params });

try {
  await client.connect(new StdioClientTransport({
    command: process.execPath,
    args: [fileURLToPath(new URL('../../game-mcp-server/dist/index.js', import.meta.url))],
    env: { ...process.env, GAME_SERVER_URL: endpoint },
    stderr: 'pipe',
  }));
  check((await client.listTools()).tools.length === 8, 'Existing adapter retains eight tools');
  check((await call('game_health')).engine === 'Godot', 'Health identifies Godot');
  await action('mainMenu');
  check((await call('game_list_actions')).actions.length === 2, 'Menu exposes two setup actions');
  await call('game_tap', { node: 'Settings' });
  const beforeMusic = (await call('game_nodes')).find(node => node.name === 'Music');
  check(Boolean(beforeMusic) && beforeMusic.type === 'CheckButton', 'Settings toggle is discoverable');
  await call('game_tap', { node: 'Music' });
  const afterMusic = (await call('game_nodes')).find(node => node.name === 'Music');
  check(beforeMusic.properties.checked !== afterMusic.properties.checked, 'Debug tap toggles CheckButton through its signal');
  await call('game_tap', { node: 'Music' });
  await call('game_tap', { node: 'Back' });
  for (let level = 0; level <= 5; level++) {
    await action('loadLevel', { level: String(level) });
    const paused = await action('pause');
    check(paused.gameState.levelNumber === level, `Migrated level ${level} loads through unchanged MCP adapter`);
    check(paused.gameState.gameStatus === 'paused' && paused.gameState.isPaused, 'Pause state contract matches Swift');
    for (const field of ['score', 'lives', 'resources', 'elapsedTime', 'playerPosition', 'hermesPosition', 'playerHealth', 'hermesHealth', 'enemyCount', 'towerCount']) {
      check(paused.gameState[field] !== undefined, `Structured state includes ${field}`);
    }
  }
  await action('loadLevel', { level: '0' });
  await action('pause');
  const initial = await call('game_state');
  await action('spawnEnemy', { type: 'soldier', x: '100', y: '100' });
  const spawned = await call('game_state');
  check(spawned.enemyCount === initial.enemyCount + 1, 'Repeatable enemy setup works while paused');
  await action('addResources', { amount: '12' });
  check((await call('game_state')).resources === initial.resources + 12, 'Resource setup updates exact state');
  await action('healPlayer');
  const nodes = await call('game_nodes');
  check(nodes.length > 0 && nodes.every(node => node.frame && node.interactive), 'Modal controls expose viewport bounds');
  const resume = nodes.find(node => /resume/i.test(node.name));
  check(Boolean(resume), 'Resume button is discoverable');
  await call('game_tap', { node: resume.name });
  check(!(await call('game_state')).isPaused, 'Named tap dispatches real Godot button handler');
  await action('setHermesMode', { mode: 'independent' });
  check((await call('game_state')).hermesMode === 'independent', 'Hermes independent mode preserves protocol spelling');
  await action('setHermesMode', { mode: 'following' });
  const worldNodes = await call('game_nodes');
  check(worldNodes.some(node => node.name === 'nathaniel'), 'World entity can be located by name');
  const player = worldNodes.find(node => node.name === 'nathaniel').frame;
  await call('game_swipe', { fromX: player.x, fromY: player.y, toX: player.x, toY: player.y });
  await action('pause');
  await action('killAllEnemies');
  check((await call('game_state')).enemyCount === 0, 'Survival kill setup runs ordinary death handling');
  for (const args of [
    { name: 'loadLevel', params: { level: '99' } },
    { name: 'spawnEnemy', params: { type: 'soldier' } },
    { name: 'addResources', params: { amount: '9223372036854775807' } },
    { name: 'setHermesMode', params: { mode: 'following' } },
  ]) check((await client.callTool({ name: 'game_action', arguments: args })).isError, 'Invalid setup returns a tool error');
  const screenshot = await client.callTool({ name: 'game_screenshot' });
  check(screenshot.isError && /headless/.test(screenshot.content[0].text), 'Headless screenshot explicitly reports unavailable');
  await action('mainMenu');
  check((await call('game_state')).scene === 'MainMenuScene', 'Main menu discards isolated session');
  console.log(`Live Godot MCP: ${checks} checks passed`);
} finally {
  await client.close();
}
