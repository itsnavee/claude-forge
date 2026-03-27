---
name: my-prompt-history
description: Use when you need to see what prompts were used recently — shows last N user prompts from current session or all sessions. Also use for "show my prompts", "what did I ask", or "prompt history".
argument-hint: "< N (default 10) | all (all sessions) >"
allowed-tools: Bash(python3:*)
---

# /my-prompt-history

Run the script and print its output. Do NOT summarize, rephrase, or add commentary. Just execute and display.

```
python3 ~/.claude/skills/my-prompt-history/show-prompts.py {argument} {cwd}
```

- `{argument}` = the user's argument (number or "all"). Default: `10` if no argument given.
- `{cwd}` = current working directory (pass literally).

That's it. No further action needed.

## Gotchas

- Session JSONL files can be very large — reading all of them fills context quickly
- Prompts from compacted sessions may be truncated or missing
