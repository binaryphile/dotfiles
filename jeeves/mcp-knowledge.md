# MCP (Model Context Protocol) Setup Guide for Claude Code CLI

## The Critical Bug

Claude Code CLI has a command parsing bug where it treats the entire command string as a single executable instead of properly parsing command and arguments.

### Error Pattern
```
spawn npx -y @modelcontextprotocol/server-filesystem /path ENOENT
```

This happens because Claude Code tries to execute:
- ❌ `"npx -y @modelcontextprotocol/server-filesystem /path"` (as one string)

Instead of:
- ✅ Command: `npx`, Args: `["-y", "@modelcontextprotocol/server-filesystem", "/path"]`

## The Solution: Wrapper Scripts

Create a shell script wrapper that provides a single executable for Claude Code to spawn.

### Example Wrapper Script
```bash
#!/bin/bash
# mcp-wrapper.sh
exec npx -y @modelcontextprotocol/server-filesystem /home/user/directory
```

### Setup Steps
1. Create wrapper script
2. Make it executable: `chmod +x mcp-wrapper.sh`
3. Add to Claude Code: `claude mcp add -s user servername "/full/path/to/mcp-wrapper.sh"`
4. Reload Claude Code

## MCP Server Requirements

### Core Protocol Rules
1. **stdout is SACRED**: Only JSON-RPC messages, no console.log()
2. **stderr for logging**: All debug output goes here
3. **Newline-delimited**: Each JSON-RPC message on its own line

### Essential npm Packages
```json
{
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.5.0"
  }
}
```

### MCP Server Template
```javascript
#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';

const server = new Server(
  { name: 'my-server', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

// Use the schema objects for request handlers
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [{
    name: 'my_tool',
    description: 'Tool description',
    inputSchema: {
      type: 'object',
      properties: {
        param: { type: 'string', description: 'Parameter description' }
      },
      required: ['param']
    }
  }]
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case 'my_tool':
      // Tool implementation
      return {
        content: [{
          type: 'text',
          text: `Result for ${args.param}`
        }]
      };
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error('MCP server running on stdio'); // Use stderr!
```

## Debugging MCP Connections

### Check Status
- In Claude Code chat: `/mcp`
- Command line: `claude mcp list`

### View Logs
Logs are stored in: `~/.cache/claude-cli-nodejs/-home-user-project/mcp-logs-servername/`

### Common Issues and Fixes

1. **spawn ENOENT**: Use wrapper script (see above)
2. **Node not found**: Use absolute path to node in wrapper
3. **Nix environment**: Run `nix develop` before starting Claude Code
4. **Windows**: Prefix commands with `cmd /c`

## Configuration Scopes

- **User scope** (`-s user`): Available in all projects
- **Project scope**: Shared via `.mcp.json`
- **Local scope**: Private to you in current project

## Working Example

Here's a complete working setup for the filesystem MCP:

1. **Wrapper script** (`filesystem-mcp.sh`):
```bash
#!/bin/bash
exec npx -y @modelcontextprotocol/server-filesystem "$HOME/Documents"
```

2. **Install**:
```bash
chmod +x filesystem-mcp.sh
claude mcp add -s user filesystem "$PWD/filesystem-mcp.sh"
```

3. **Verify**: After reloading Claude Code, `/mcp` should show:
```
filesystem ✓ Connected
```

## Key Takeaways

1. **Always use wrapper scripts** for any command with arguments
2. **Use absolute paths** in wrapper scripts
3. **Check logs** when debugging connection failures
4. **Never write to stdout** in your MCP server code
5. **Test with official servers first** (filesystem, github, etc.)

## Advanced Debugging

### Understanding the Error Logs

1. **Find your logs**:
```bash
ls ~/.cache/claude-cli-nodejs/-home-*/mcp-logs-*/
```

2. **Read the latest log**:
```bash
cat ~/.cache/claude-cli-nodejs/-home-*/mcp-logs-servername/$(ls -t ~/.cache/claude-cli-nodejs/-home-*/mcp-logs-servername/ | head -1)
```

### Common Error Patterns

#### spawn ENOENT
```json
"Error: spawn npx -y @modelcontextprotocol/server-filesystem /path ENOENT"
```
**Cause**: Claude Code treating entire command as one executable
**Fix**: Use wrapper script

#### Protocol Errors
```json
"error": "Invalid JSON-RPC response"
```
**Cause**: Server writing non-JSON to stdout
**Fix**: Remove all console.log(), use console.error() for debugging

#### Connection Timeout
```json
"error": "Connection timeout after 5000ms"
```
**Cause**: Server crashed or hanging during initialization
**Fix**: Test server manually, check for missing dependencies

### Testing Your MCP Server

1. **Manual test**:
```bash
# Should output "MCP server running on stdio" to stderr
./your-mcp-wrapper.sh
# Press Ctrl+C to exit
```

2. **JSON-RPC test**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | ./your-mcp-wrapper.sh
```

3. **Verify clean stdout**:
```bash
# Should see ONLY JSON output
./your-mcp-wrapper.sh 2>/dev/null
```

### Debug Mode

Run Claude Code with debug output:
```bash
claude --debug
```

This shows MCP connection attempts inline with your conversation.

### Troubleshooting Checklist

- [ ] Wrapper script is executable (`chmod +x`)
- [ ] Wrapper uses absolute paths
- [ ] No output to stdout except JSON-RPC
- [ ] Server runs without errors when tested manually
- [ ] Node/npm accessible from wrapper script
- [ ] All dependencies installed
- [ ] Using appropriate configuration scope (-s user for global access)

### Getting Help

When reporting issues, include:
1. Output of `claude mcp list`
2. Contents of latest log file
3. Your wrapper script
4. Output of manually running the wrapper

## Online Resources Quality Assessment

### Ranked by Usefulness (Best First)

1. **GitHub Source Code** (⭐⭐⭐⭐⭐)
   - https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem/index.ts
   - **Why it's best**: Actual working implementations show the correct patterns
   - **Key insight**: Revealed the need for `CallToolRequestSchema` and `ListToolsRequestSchema` imports
   - **Tip**: Always check the source code of official servers for implementation patterns

2. **Claude Code MCP Documentation** (⭐⭐⭐⭐)
   - https://docs.anthropic.com/en/docs/claude-code/mcp
   - **Strengths**: Good overview and troubleshooting steps
   - **Weakness**: Lacks detailed implementation examples
   - **Best for**: Understanding concepts and debugging

3. **MCP Server Examples Repository** (⭐⭐⭐)
   - https://github.com/modelcontextprotocol/servers
   - **Strengths**: Lists available servers and their capabilities
   - **Weakness**: README doesn't show implementation details
   - **Best for**: Finding examples to study

4. **MCP Specification** (⭐⭐)
   - https://spec.modelcontextprotocol.io/ (redirects to modelcontextprotocol.io)
   - **Issue**: The spec site seems incomplete or focuses on versioning
   - **Limited usefulness**: Didn't provide practical implementation guidance
   - **Best for**: Understanding protocol versioning

### Key Learning

The most valuable resource is always the source code. Documentation often omits critical details like:
- Import syntax for request schemas
- Exact method signatures
- Error handling patterns

## References
- Official MCP Servers: https://github.com/modelcontextprotocol/servers
- MCP Specification: https://spec.modelcontextprotocol.io/
- Claude Code MCP Docs: https://docs.anthropic.com/en/docs/claude-code/mcp
- TypeScript SDK: https://github.com/modelcontextprotocol/typescript-sdk
