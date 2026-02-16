| description | disable-model-invocation |
|---|---|
| Start the observability dashboard (server + client) | false |

Start the Multi-Agent Observability dashboard by running the start script.

Use the Bash tool to run:
```
${CLAUDE_PLUGIN_ROOT}/scripts/start-system.sh
```

Run it in the background so it doesn't block the session. After starting, inform the user:
- Dashboard URL: http://localhost:5173
- Server API: http://localhost:4000
- WebSocket: ws://localhost:4000/stream

If it fails, check that `bun` is installed and that `bun install` has been run in both `${CLAUDE_PLUGIN_ROOT}/apps/server` and `${CLAUDE_PLUGIN_ROOT}/apps/client`.
