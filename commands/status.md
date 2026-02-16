| description | disable-model-invocation |
|---|---|
| Check observability dashboard health | false |

Check if the observability server and client are running.

Use the Bash tool to run these health checks:
```bash
curl -sf http://localhost:4000/health > /dev/null 2>&1 && echo "Server: UP (port 4000)" || echo "Server: DOWN (port 4000)"
curl -sf http://localhost:5173 > /dev/null 2>&1 && echo "Client: UP (port 5173)" || echo "Client: DOWN (port 5173)"
```

Report the status to the user. If both are up, remind them the dashboard is at http://localhost:5173.
If either is down, suggest running `/observability:start`.
