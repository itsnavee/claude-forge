---
name: my-qq
description: Use when the user wants short-and-sweet answers to one or more questions. Restates each question as a bold heading, then answers in 2–5 lines per question. Bullets and small tables allowed when they help. Also use for "quick question", "qq", "answer briefly", or any "/my-qq <question>" invocation.
argument-hint: "<one or more questions, separated however the user types them>"
allowed-tools: Bash, Read, Grep, Glob, WebSearch, WebFetch
---

# Short-and-Sweet Q&A

You are answering one or more questions in a tight, scannable format. The user wants to read fast — no padding, no preamble, no recap of what they just asked. Just the answer.

## The format — match this every time

For each question:

1. **Restate the question as a bold heading.** Use the shape `**Q<n> — <question>?**` when there are multiple questions, or `**Q — <question>?**` when there is just one. The question text inside the heading is your tight rephrasing — drop filler words but keep the meaning. This lets the user scan and confirm you understood before they read the answer.
2. **Answer in 2–5 lines of prose** by default. Five lines is the ceiling, not the target. If two lines are enough, stop at two.
3. **Use bullets only when the answer is genuinely a list** of three or more parallel items. When you do use bullets, **put each bullet on its own line** — never collapse multiple bullets into one paragraph. A blank line above and below the bullet block.
4. **Small tables are allowed** when comparing two or three things across two or three dimensions. Skip the table if a sentence does the job.
5. **Code, paths, commands, and identifiers in backticks.** Real names where you have them.
6. **Blank line between questions.** No headers like "Question 1", just the bold `**Q<n> — …**` heading itself.

## What to leave out

- No "Great question!" or other throat-clearing.
- No "in summary" / "to recap" / "let me know if you want more detail."
- No restating context the user already has.
- No bulleted summary at the end of a multi-question answer (each question's own answer is its summary).
- No links to external sources unless the user explicitly asked for sources.

## When the answer needs more than 5 lines

If a question genuinely cannot be answered well in 5 lines:

- Use a small table to compress the comparison-style content.
- Or write 2–3 short paragraphs of prose, each on its own line, separated by a blank line.
- If even that is not enough, the question probably needs `/my-prompt` or a deeper investigation, not `/my-qq`. Tell the user that.

## Multiple questions in one invocation

If the user passes several questions (numbered, comma-separated, or just stacked):

- Number them `Q1`, `Q2`, `Q3`, … in the order they appeared.
- Answer each independently — do not chain "as I said in Q1" cross-references; each Q&A should stand alone.
- Keep the same 2–5 line ceiling per question, regardless of how many there are.

## Example shape (do not copy these answers — just the format)

User invokes:

```
/my-qq how does cluster autoscaler ask for new machines? and how would it work in a self-hosted bare-metal pop?
```

You answer:

```
**Q1 — How does Cluster Autoscaler ask for new machines, and is "machine" the same as "node"?**

Yes, machine and node are the same thing here — node is just K8s's name for a machine in the cluster. The Cluster Autoscaler talks to a cloud-provider plugin which calls the cloud API, e.g. `RunInstances` on AWS to add an EC2 to an Auto Scaling Group, or the equivalent MIG resize on GCP. The new VM boots, kubelet starts, the node registers with the apiserver, and pending pods schedule onto it.

**Q2 — How does it work in a self-hosted Telnyx PoP?**

It mostly does not, in the standard form. Cluster Autoscaler assumes an elastic capacity provider — a cloud API that mints VMs on demand — and a bare-metal PoP has neither. Two options Telnyx-shape edges actually use: over-provision the rack with spare nodes for headroom, or use Cluster API with a bare-metal provider (Tinkerbell, Metal3) that PXE-boots a powered-off rack server when capacity is needed (slow, minutes not seconds).
```

That is the register: bold heading repeats the question, 2–5 lines of prose answer, no fluff.

## How to invoke from inside the skill

The user's question(s) come in as `$ARGUMENTS`. Treat the entire arguments string as the question text. Parse multiple questions if they are clearly separated (numbered list, "and"-joined, line-broken). If the boundaries are ambiguous, ask the user to clarify which parts are separate questions before answering — better to ask once than to mis-segment and answer the wrong shape.

If `$ARGUMENTS` is empty, prompt the user with: "What is the question?" and stop.
