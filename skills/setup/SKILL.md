---
description: Wire the usage-guard statusline into your Claude Code settings in one step. Run once after installing the plugin.
disable-model-invocation: true
---

Wire the usage-guard statusline for the user by running this command, then report what it prints:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"
```

- If it reports the statusline was wired, tell the user to restart Claude Code, or that it takes effect on the next statusline tick.
- If it reports an existing statusline was left untouched, relay the exact instructions it printed so the user can run both together.
- Re-running this after a plugin update refreshes the copied capture script.
