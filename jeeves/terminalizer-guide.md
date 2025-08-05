# Terminalizer Guide: Recording CLI Sessions as SVG

This guide shows how to record terminal sessions and convert them to animated SVG files
perfect for documentation, presentations, and web display.

## Setup in Nix Environment

Terminalizer is installed via npm in our nix development environment. To use it:

``` bash
# Enter the nix environment
nix develop

# Run terminalizer through npx
npx terminalizer --version
```

## Recording Sessions

### Start Recording

``` bash
npx terminalizer record my-demo
```

Your terminal session begins recording immediately. When finished, press `Ctrl+D` to stop.
The recording saves to `~/.terminalizer/recordings/my-demo.yml`.

### Recording Options

``` bash
# Add a title
npx terminalizer record my-demo -t "Claude Code Demo"

# Record a specific command
npx terminalizer record my-demo -c "claude chat"

# Skip the confirmation prompt
npx terminalizer record my-demo -k
```

## Generating SVG Output

Convert your recording to an animated SVG:

``` bash
npx terminalizer render my-demo -o my-demo.svg
```

This creates a self-contained SVG file that works anywhere - no JavaScript or external
dependencies required.

## Configuration

Create `~/.terminalizer/config.yml` to customize the appearance:

``` yaml
# Terminal dimensions
cols: 80
rows: 24

# Animation settings
repeat: 0
quality: 100
frameDelay: auto
maxIdleTime: 2000

# Window styling
frameBox:
  type: solid
  title: null
  style:
    boxShadow: none
    margin: 0px

# Remove watermark
watermark:
  imagePath: null

# Font configuration
fontFamily: "Monaco, Consolas, Ubuntu Mono, monospace"
fontSize: 14
lineHeight: 1.2
letterSpacing: 0

# GitHub Dark theme
theme:
  background: "#0d1117"
  foreground: "#c9d1d9"
  cursor: "#c9d1d9"
  black: "#484f58"
  red: "#ff7b72"
  green: "#3fb950"
  yellow: "#d29922"
  blue: "#58a6ff"
  magenta: "#bc8cff"
  cyan: "#39c5cf"
  white: "#b1bac4"
  brightBlack: "#6e7681"
  brightRed: "#ffa198"
  brightGreen: "#56d364"
  brightYellow: "#e3b341"
  brightBlue: "#79c0ff"
  brightMagenta: "#d2a8ff"
  brightCyan: "#56d4dd"
  brightWhite: "#f0f6fc"
```

## Editing Recordings

Recordings are YAML files you can edit before rendering:

``` bash
# Edit with terminalizer
npx terminalizer edit my-demo

# Or edit directly
vim ~/.terminalizer/recordings/my-demo.yml
```

### Common Edits

**Adjust timing between commands:**

``` yaml
- delay: 5000  # Reduce to 2000 for faster playback
  content: 'ls -la'
```

**Remove mistakes:** Delete unwanted frames from the YAML file

**Cap long pauses:** Set `maxIdleTime: 2000` in config to limit idle periods

## Tips for Recording Claude Sessions

1.  **Set consistent terminal size** - Use 80x24 for best compatibility
2.  **Clear before starting** - Run `clear` for a clean slate
3.  **Type steadily** - Maintain a natural pace
4.  **Use Ctrl+L** - Clear screen during recording if needed
5.  **Plan your demo** - Know your commands beforehand

## Displaying SVG Files

### In Obsidian

``` markdown
![[my-demo.svg]]
```

### In HTML

``` html
<img src="my-demo.svg" alt="Terminal Demo" width="100%">
```

### In Markdown

``` markdown
![Terminal Demo](my-demo.svg)
```

### Direct embed

``` html
<object data="my-demo.svg" type="image/svg+xml"></object>
```

## Workflow Example

Here’s a complete recording workflow:

``` bash
# 1. Enter nix environment
nix develop

# 2. Start recording
npx terminalizer record claude-demo -t "MCP Server Setup"

# 3. Run your demo
clear
echo "Setting up an MCP server for Claude Code..."
cd .mcp
cat jira-server.js
# ... more commands ...

# 4. Stop recording (Ctrl+D)

# 5. Optional: Edit the recording
npx terminalizer edit claude-demo

# 6. Render to SVG
npx terminalizer render claude-demo -o claude-demo.svg

# 7. View the result
open claude-demo.svg
```

## Advanced Options

### Additional Render Settings

``` bash
# High quality output
npx terminalizer render my-demo -o my-demo.svg -q 100

# Skip frame box
npx terminalizer render my-demo -o my-demo.svg --skip-sharing-dialog
```

### Other Output Formats

``` bash
# Generate GIF
npx terminalizer render my-demo -o my-demo.gif

# Convert GIF to MP4
ffmpeg -i my-demo.gif -movflags faststart -pix_fmt yuv420p my-demo.mp4
```

### Share Online

``` bash
# Upload and get shareable link
npx terminalizer share my-demo
```

## Troubleshooting

**SVG won’t animate:** Ensure your browser supports SVG animation. Try opening directly in
Chrome or Firefox.

**Recording too large:** Edit the YAML to remove unnecessary frames or increase maxIdleTime.

**Wrong colors:** Check your terminal’s color support and adjust the theme in config.yml.

**Command not found:** Make sure you’re in the nix develop environment before running
terminalizer.

## Why SVG?

SVG output is ideal because it’s: - Self-contained with no external dependencies - Scalable
without quality loss - Perfect for documentation and web display - Easy to embed in any
modern browser - Smaller file size than GIF for long recordings

Your recorded terminal sessions are now portable, professional, and ready to share!
