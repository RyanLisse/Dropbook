#!/bin/bash
# Dropbook MCP server launcher for reloaderoo testing

# Load environment variables from ~/.clawdbot/dropbox.env if it exists
if [ -f ~/.clawdbot/dropbox.env ]; then
    export $(cat ~/.clawdbot/dropbox.env | grep -v '^#' | xargs)
fi

# Run dropbook in MCP mode
/Users/shelton/Developer/Dropbook/.build/debug/dropbook mcp
