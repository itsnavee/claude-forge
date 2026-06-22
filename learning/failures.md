# Failures

Debugging sessions, bugs that took significant effort, things that broke unexpectedly.

### 2026-03-14 — macOS date %P format doesn't produce lowercase am/pm
**Project**: claude-config
**Context**: Timezone clocks showed "10:07P" instead of "10:07pm". `%P` is a GNU extension — macOS date doesn't support it the same way.
**Learning**: On macOS, use `date +"%l:%M%p"` then pipe through `tr '[:upper:]' '[:lower:]'` and `sed 's/\.//g'` to get clean lowercase am/pm.



### 2026-05-24 — sed via find -exec gets blocked; per-file loop works
**Project**: my-project
**Context**: tried `find ... -name "*.py" -exec sed -i '...' {} \;` to bulk-rewrite imports across forklifted files. Got rejected ("rtk find does not support compound predicates").
**Learning**: skip `find -exec`; use a per-file `for f in <list>; do sed -i '...' "$f"; done`. Always verify with a follow-up grep — the first attempt silently completed without applying.


### 2026-05-24 — Next.js 16 deprecated middleware.ts → proxy.ts; Clerk quickstart was right
**Project**: my-project
**Context**: Followed Clerk's official quickstart but flagged its `proxy.ts` instruction as a "deviation" and used `middleware.ts` instead. Next.js 16 dev server immediately warned: "The middleware file convention is deprecated. Please use proxy instead."
**Learning**: When a framework's official quickstart says something unusual, trust it before assuming you know better. The cost of being wrong was ~1 min to rename. Skim recent framework changelogs before "correcting" docs.


### 2026-05-24 — `printenv $VAR` leaks values to chat transcript; never echo secrets
**Project**: my-project
**Context**: Generated POSTGRES_PASSWORD + BETTER_AUTH_SECRET via openssl, then ran `doppler run -- printenv POSTGRES_PASSWORD BETTER_AUTH_SECRET DATABASE_URL` with a `sed 's/=.*/=[REDACTED]/'` filter expecting redaction. The filter does NOTHING because printenv outputs only VALUES (no `KEY=`). Burned both secrets.
**Learning**: Never echo any secret value to stdout for verification. Use length checks (`${VAR:0:4}…${VAR: -4}`) or boolean checks (`[ -n "$VAR" ] && echo set`). Test redaction logic on a synthetic value before using on real secrets.


### 2026-05-24 — `doppler secrets set KEY=__PLACEHOLDER__` crashed sentry.init at app boot
**Project**: my-project
**Context**: Seeded placeholders for ~20 env vars in Doppler to "lay out the structure." Sentry-SDK trying to parse `__PLACEHOLDER__` as a DSN URL crashed the FastAPI startup. The truthy-check `if settings.sentry_dsn:` evaluated true for the placeholder.
**Learning**: Don't seed truthy placeholders for SDKs that validate config strictly at init. Either leave the var unset (Pydantic defaults to "" → falsy → SDK init skipped), or use a structurally-valid example (https://example.invalid for URLs).


### 2026-05-29 — Tailwind star-rating clip: three stacked bugs
**Project**: yumeloom
**Context**: Fractional star ratings all rendered as full 5. Caused by: (1) `absolute inset-0` sets left+right:0 which overrides `width:%`; (2) flex stars shrank to fit instead of clipping (needed `shrink-0`); (3) container stretched by parent flex-column so `%` was relative to full width not the stars.
**Learning**: For a clipped overlay use `inset-y-0 left-0` (not `inset-0`), `shrink-0` on flex children inside `overflow-hidden`, and `w-fit`/`self-start` so the % is relative to content. Verify with measured px (getBoundingClientRect), not the inline style string.



### 2026-05-29 — react-icons fa6 vs fa5 name killed the whole footer
**Project**: yumeloom
**Context**: Imported `FaSnapchatGhost` (a Font Awesome 5 name) from `react-icons/fa6` → it's `undefined` in fa6, which threw "Unsupported Server Component type: undefined" and crashed the entire footer SSR (not just the icon).
**Learning**: A single undefined icon import takes down the whole RSC subtree. In fa6 it's `FaSnapchat`. When adding react-icons, verify each name exists: `node -e "console.log(typeof require('react-icons/fa6').FaX)"`.

