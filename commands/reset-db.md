| description | disable-model-invocation |
|---|---|
| Clear the observability event database | false |

Clear all events from the observability database. This removes all stored hook events, chat transcripts, and session data.

**Ask the user for confirmation before proceeding** — this action is destructive and cannot be undone.

If confirmed, use the Bash tool to delete the database files:
```bash
rm -f ${CLAUDE_PLUGIN_ROOT}/apps/server/events.db ${CLAUDE_PLUGIN_ROOT}/apps/server/events.db-wal ${CLAUDE_PLUGIN_ROOT}/apps/server/events.db-shm
```

The database will be automatically recreated when the server next starts.
