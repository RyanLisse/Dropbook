#!/bin/bash
# Test Dropbook MCP server directly

echo "Testing Dropbook MCP Server..."
echo ""

# Set up environment
if [ -f ~/.clawdbot/dropbox.env ]; then
    source ~/.clawdbot/dropbox.env
fi

# Test 1: Check if binary exists
if [ ! -f /Users/shelton/Developer/Dropbook/.build/debug/dropbook ]; then
    echo "❌ Error: dropbook binary not found"
    exit 1
fi

echo "✅ Binary found"

# Test 2: Try to run MCP server
echo ""
echo "Testing MCP server..."
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | /Users/shelton/Developer/Dropbook/.build/debug/dropbook mcp 2>&1 &
DROPBOOK_PID=$!
sleep 3

# Test 3: Send ping
echo '{"jsonrpc":"2.0","id":2,"method":"ping"}' | /Users/shelton/Developer/Dropbook/.build/debug/dropbook mcp 2>&1 &
PING_PID=$!
sleep 3

# Cleanup
kill $DROPBOOK_PID 2>/dev/null
kill $PING_PID 2>/dev/null

echo ""
echo "✅ Tests complete"
