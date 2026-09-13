import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { test } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

// Exercise the real MCP stdio process against an isolated HTTP fixture.
test('small tool interface forwards requests and reports failures', async (t) => {
  const requests = [];
  const http = createServer(async (req, res) => {
    let body = '';
    for await (const chunk of req) body += chunk;
    requests.push({ method: req.method, path: req.url, body: body ? JSON.parse(body) : null });
    res.setHeader('Content-Type', 'application/json');
    if (req.url === '/screenshot') {
      res.end(JSON.stringify({ success: true, format: 'png', data: 'aW1hZ2U=' }));
    } else if (req.url === '/action') {
      res.end(JSON.stringify({ success: false, error: 'Invalid level' }));
    } else if (req.url === '/nodes') {
      res.writeHead(503).end(JSON.stringify({ error: 'No scene' }));
    } else {
      res.end(JSON.stringify({ success: true, scene: 'GameScene', status: 'ok' }));
    }
  });
  http.listen(0, '127.0.0.1');
  await once(http, 'listening');
  const client = new Client({ name: 'test', version: '1.0.0' });
  t.after(async () => {
    await client.close();
    http.closeAllConnections();
    await new Promise(resolve => http.close(resolve));
  });
  await client.connect(new StdioClientTransport({
    command: process.execPath,
    args: ['dist/index.js'],
    env: { ...process.env, GAME_SERVER_URL: `http://127.0.0.1:${http.address().port}` },
    stderr: 'pipe',
  }));
  await t.test('exposes only the supported tools', async () => {
    const { tools } = await client.listTools();
    assert.deepEqual(tools.map(tool => tool.name).sort(), [
      'game_health', 'game_state', 'game_nodes', 'game_screenshot',
      'game_list_actions', 'game_action', 'game_tap', 'game_swipe',
    ].sort());
  });
  await t.test('passes state through and returns a native image', async () => {
    const state = await client.callTool({ name: 'game_state' });
    assert.equal(JSON.parse(state.content[0].text).scene, 'GameScene');
    const shot = await client.callTool({ name: 'game_screenshot' });
    assert.deepEqual(shot.content, [{ type: 'image', mimeType: 'image/png', data: 'aW1hZ2U=' }]);
  });
  await t.test('forwards named taps and viewport swipes', async () => {
    await client.callTool({ name: 'game_tap', arguments: { node: 'pauseButton' } });
    assert.deepEqual(requests.at(-1), { method: 'POST', path: '/tap', body: { node: 'pauseButton' } });
    await client.callTool({ name: 'game_swipe', arguments: { fromX: 1, fromY: 2, toX: 3, toY: 4 } });
    assert.deepEqual(requests.at(-1).body, { fromX: 1, fromY: 2, toX: 3, toY: 4, duration: 0.3 });
  });
  await t.test('marks game and HTTP failures as tool errors', async () => {
    const action = await client.callTool({ name: 'game_action', arguments: { name: 'loadLevel', params: { level: '99' } } });
    assert.equal(action.isError, true);
    assert.match(action.content[0].text, /Invalid level/);
    assert.deepEqual(requests.at(-1).body, { name: 'loadLevel', params: { level: '99' } });
    const nodes = await client.callTool({ name: 'game_nodes' });
    assert.equal(nodes.isError, true);
    assert.match(nodes.content[0].text, /503/);
  });
  await t.test('rejects invalid input before HTTP', async () => {
    const count = requests.length;
    for (const call of [
      { name: 'game_tap', arguments: { x: 1 } },
      { name: 'game_action', arguments: { name: 'loadLevel', params: { level: 2 } } },
      { name: 'game_swipe', arguments: { fromX: 1, fromY: 2, toX: 3, toY: 4, duration: -1 } },
      { name: 'game_get_state' },
    ]) {
      assert.equal((await client.callTool(call)).isError, true);
    }
    assert.equal(requests.length, count);
  });
});
