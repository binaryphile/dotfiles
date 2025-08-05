#!/usr/bin/env node

import { spawn } from 'child_process';
import { promisify } from 'util';

const sleep = promisify(setTimeout);

async function testMCPServer() {
  console.log('Starting MCP server smoke test...\n');

  // Spawn the MCP server
  const server = spawn('nix', ['develop', '/home/ted/dotfiles/jeeves', '--quiet', '-c', 'node', '/home/ted/dotfiles/jeeves/mcp-tmux-control.js'], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  let response = '';
  let errorOutput = '';

  server.stdout.on('data', (data) => {
    response += data.toString();
    console.log('STDOUT:', data.toString());
  });

  server.stderr.on('data', (data) => {
    errorOutput += data.toString();
    console.log('STDERR:', data.toString());
  });

  server.on('error', (err) => {
    console.error('Failed to start server:', err);
  });

  // Wait a moment for server to start
  await sleep(1000);

  // Send initialize request
  const initRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: {
        name: 'test-client',
        version: '1.0.0'
      }
    }
  };

  console.log('\nSending initialize request...');
  server.stdin.write(JSON.stringify(initRequest) + '\n');

  // Wait for response
  await sleep(1000);

  // Send list tools request
  const listToolsRequest = {
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/list',
    params: {}
  };

  console.log('\nSending tools/list request...');
  server.stdin.write(JSON.stringify(listToolsRequest) + '\n');

  // Wait for response
  await sleep(1000);

  // Test calling a tool
  const callToolRequest = {
    jsonrpc: '2.0',
    id: 3,
    method: 'tools/call',
    params: {
      name: 'tmux_list_sessions',
      arguments: {}
    }
  };

  console.log('\nSending tools/call request for tmux_list_sessions...');
  server.stdin.write(JSON.stringify(callToolRequest) + '\n');

  // Wait and then close
  await sleep(2000);

  console.log('\n--- Final Results ---');
  console.log('Total stdout received:', response.length, 'bytes');
  console.log('Total stderr received:', errorOutput.length, 'bytes');
  
  if (response) {
    console.log('\nParsing responses...');
    const lines = response.split('\n').filter(line => line.trim());
    for (const line of lines) {
      try {
        const parsed = JSON.parse(line);
        console.log('\nParsed response:', JSON.stringify(parsed, null, 2));
      } catch (e) {
        console.log('Non-JSON line:', line);
      }
    }
  }

  server.kill();
}

testMCPServer().catch(console.error);