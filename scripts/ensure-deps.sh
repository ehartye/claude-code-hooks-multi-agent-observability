#!/bin/bash
# Check and install dependencies for the observability plugin.
# Verifies bun and uv are available, then installs node dependencies.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Resolve plugin root
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

errors=0

# Check for bun
if command -v bun &> /dev/null; then
    echo -e "${GREEN}[ok]${NC} bun $(bun --version)"
else
    echo -e "${RED}[missing]${NC} bun — install from https://bun.sh"
    errors=$((errors + 1))
fi

# Check for uv
if command -v uv &> /dev/null; then
    echo -e "${GREEN}[ok]${NC} uv $(uv --version 2>/dev/null || echo '(version unknown)')"
else
    echo -e "${RED}[missing]${NC} uv — install from https://docs.astral.sh/uv/"
    errors=$((errors + 1))
fi

if [ $errors -gt 0 ]; then
    echo -e "\n${RED}Missing $errors required tool(s). Install them and try again.${NC}"
    exit 1
fi

# Install node dependencies if needed
if [ ! -d "$PLUGIN_ROOT/apps/server/node_modules" ]; then
    echo -e "${YELLOW}Installing server dependencies...${NC}"
    cd "$PLUGIN_ROOT/apps/server" && bun install
fi

if [ ! -d "$PLUGIN_ROOT/apps/client/node_modules" ]; then
    echo -e "${YELLOW}Installing client dependencies...${NC}"
    cd "$PLUGIN_ROOT/apps/client" && bun install
fi

echo -e "${GREEN}All dependencies ready.${NC}"
