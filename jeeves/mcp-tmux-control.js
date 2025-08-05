#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

class TmuxControlServer {
  constructor() {
    this.server = new Server(
      {
        name: 'tmux-control',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'tmux_send_keys',
          description: 'Send keystrokes to a tmux pane',
          inputSchema: {
            type: 'object',
            properties: {
              session: {
                type: 'string',
                description: 'Tmux session name',
              },
              window: {
                type: 'string',
                description: 'Window identifier (number or name)',
                default: '0',
              },
              pane: {
                type: 'string',
                description: 'Pane identifier',
                default: '0',
              },
              keys: {
                type: 'string',
                description: 'Keys to send (use "Enter" for return key)',
              },
            },
            required: ['session', 'keys'],
          },
        },
        {
          name: 'tmux_capture_pane',
          description: 'Capture the contents of a tmux pane',
          inputSchema: {
            type: 'object',
            properties: {
              session: {
                type: 'string',
                description: 'Tmux session name',
              },
              window: {
                type: 'string',
                description: 'Window identifier',
                default: '0',
              },
              pane: {
                type: 'string',
                description: 'Pane identifier',
                default: '0',
              },
              history: {
                type: 'boolean',
                description: 'Include scrollback history',
                default: false,
              },
            },
            required: ['session'],
          },
        },
        {
          name: 'tmux_list_sessions',
          description: 'List all tmux sessions',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'tmux_new_session',
          description: 'Create a new tmux session',
          inputSchema: {
            type: 'object',
            properties: {
              session: {
                type: 'string',
                description: 'Session name',
              },
              detached: {
                type: 'boolean',
                description: 'Create session detached',
                default: true,
              },
              command: {
                type: 'string',
                description: 'Initial command to run',
              },
            },
            required: ['session'],
          },
        },
        {
          name: 'tmux_kill_session',
          description: 'Kill a tmux session',
          inputSchema: {
            type: 'object',
            properties: {
              session: {
                type: 'string',
                description: 'Session name to kill',
              },
            },
            required: ['session'],
          },
        },
        {
          name: 'tmux_split_window',
          description: 'Split a tmux window into panes',
          inputSchema: {
            type: 'object',
            properties: {
              session: {
                type: 'string',
                description: 'Tmux session name',
              },
              window: {
                type: 'string',
                description: 'Window identifier',
                default: '0',
              },
              vertical: {
                type: 'boolean',
                description: 'Split vertically (side by side)',
                default: false,
              },
              percent: {
                type: 'integer',
                description: 'Percentage size of new pane',
                default: 50,
              },
            },
            required: ['session'],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'tmux_send_keys':
            return await this.sendKeys(args);
          case 'tmux_capture_pane':
            return await this.capturePane(args);
          case 'tmux_list_sessions':
            return await this.listSessions();
          case 'tmux_new_session':
            return await this.newSession(args);
          case 'tmux_kill_session':
            return await this.killSession(args);
          case 'tmux_split_window':
            return await this.splitWindow(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async sendKeys(args) {
    const { session, window = '0', pane = '0', keys } = args;
    const target = `${session}:${window}.${pane}`;

    await execAsync(`tmux send-keys -t "${target}" "${keys}"`);

    return {
      content: [
        {
          type: 'text',
          text: `Sent keys to ${target}`,
        },
      ],
    };
  }

  async capturePane(args) {
    const { session, window = '0', pane = '0', history = false } = args;
    const target = `${session}:${window}.${pane}`;
    
    const historyFlag = history ? ' -S-' : '';
    const { stdout } = await execAsync(`tmux capture-pane -t "${target}" -p${historyFlag}`);

    return {
      content: [
        {
          type: 'text',
          text: stdout,
        },
      ],
    };
  }

  async listSessions() {
    try {
      const { stdout } = await execAsync('tmux list-sessions -F "#{session_name}: #{session_windows} windows"');
      return {
        content: [
          {
            type: 'text',
            text: stdout,
          },
        ],
      };
    } catch (error) {
      if (error.code === 1) {
        return {
          content: [
            {
              type: 'text',
              text: 'No tmux sessions found',
            },
          ],
        };
      }
      throw error;
    }
  }

  async newSession(args) {
    const { session, detached = true, command } = args;
    
    let cmd = `tmux new-session -s "${session}"`;
    if (detached) cmd += ' -d';
    if (command) cmd += ` "${command}"`;

    await execAsync(cmd);

    return {
      content: [
        {
          type: 'text',
          text: `Created session: ${session}`,
        },
      ],
    };
  }

  async killSession(args) {
    const { session } = args;
    
    await execAsync(`tmux kill-session -t "${session}"`);

    return {
      content: [
        {
          type: 'text',
          text: `Killed session: ${session}`,
        },
      ],
    };
  }

  async splitWindow(args) {
    const { session, window = '0', vertical = false, percent = 50 } = args;
    const target = `${session}:${window}`;
    
    let cmd = `tmux split-window -t "${target}" -p ${percent}`;
    if (vertical) cmd += ' -h';

    await execAsync(cmd);

    const direction = vertical ? 'vertically' : 'horizontally';
    return {
      content: [
        {
          type: 'text',
          text: `Split window ${target} ${direction}`,
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    // MCP servers must not output to stderr/stdout except for protocol messages
  }
}

const server = new TmuxControlServer();
server.run().catch(console.error);