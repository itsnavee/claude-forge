# Failures

Debugging sessions, bugs that took significant effort, things that broke unexpectedly.

### 2026-03-14 — macOS date %P format doesn't produce lowercase am/pm
**Project**: claude-config
**Context**: Timezone clocks showed "10:07P" instead of "10:07pm". `%P` is a GNU extension — macOS date doesn't support it the same way.
**Learning**: On macOS, use `date +"%l:%M%p"` then pipe through `tr '[:upper:]' '[:lower:]'` and `sed 's/\.//g'` to get clean lowercase am/pm.



### 2026-05-29 — Tailwind star-rating clip: three stacked bugs
**Project**: yumeloom
**Context**: Fractional star ratings all rendered as full 5. Caused by: (1) `absolute inset-0` sets left+right:0 which overrides `width:%`; (2) flex stars shrank to fit instead of clipping (needed `shrink-0`); (3) container stretched by parent flex-column so `%` was relative to full width not the stars.
**Learning**: For a clipped overlay use `inset-y-0 left-0` (not `inset-0`), `shrink-0` on flex children inside `overflow-hidden`, and `w-fit`/`self-start` so the % is relative to content. Verify with measured px (getBoundingClientRect), not the inline style string.


### 2026-05-29 — react-icons fa6 vs fa5 name killed the whole footer
**Project**: yumeloom
**Context**: Imported `FaSnapchatGhost` (a Font Awesome 5 name) from `react-icons/fa6` → it's `undefined` in fa6, which threw "Unsupported Server Component type: undefined" and crashed the entire footer SSR (not just the icon).
**Learning**: A single undefined icon import takes down the whole RSC subtree. In fa6 it's `FaSnapchat`. When adding react-icons, verify each name exists: `node -e "console.log(typeof require('react-icons/fa6').FaX)"`.

