# Dropbook Makefile
# Swift CLI + MCP Server for Dropbox

.PHONY: all build release clean run mcp login logout test install help

# Default target
all: build

# Build debug version
build:
	swift build

# Build release version
release:
	swift build -c release

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Run CLI (default: show help)
run:
	swift run dropbook

# Start MCP server
mcp:
	swift run dropbook mcp

# Run OAuth login flow
login:
	swift run dropbook login

# Clear stored OAuth tokens
logout:
	swift run dropbook logout

# List Dropbox root directory
list:
	swift run dropbook list /

# Run manual MCP tests
test:
	@if [ -f scripts/test-mcp.sh ]; then \
		bash scripts/test-mcp.sh; \
	else \
		echo "No test script found"; \
	fi

# Install to /usr/local/bin
install: release
	cp .build/release/dropbook /usr/local/bin/dropbook
	@echo "Installed dropbook to /usr/local/bin/dropbook"

# Uninstall from /usr/local/bin
uninstall:
	rm -f /usr/local/bin/dropbook
	@echo "Removed dropbook from /usr/local/bin"

# Show help
help:
	@echo "Dropbook - Swift CLI + MCP Server for Dropbox"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build targets:"
	@echo "  build     Build debug version (default)"
	@echo "  release   Build release version"
	@echo "  clean     Clean build artifacts"
	@echo "  install   Build release and install to /usr/local/bin"
	@echo "  uninstall Remove from /usr/local/bin"
	@echo ""
	@echo "Run targets:"
	@echo "  run       Run CLI (shows help)"
	@echo "  mcp       Start MCP server"
	@echo "  login     Run OAuth login flow"
	@echo "  logout    Clear stored OAuth tokens"
	@echo "  list      List Dropbox root directory"
	@echo "  test      Run manual MCP tests"
	@echo ""
	@echo "Environment variables required:"
	@echo "  DROPBOX_APP_KEY     Dropbox app key"
	@echo "  DROPBOX_APP_SECRET  Dropbox app secret"
	@echo ""
	@echo "After 'make login', tokens are stored in Keychain (macOS)"
	@echo "and ~/.dropbook/auth.json (backup)"
