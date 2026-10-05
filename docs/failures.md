# Failures and limits found while building

| # | Symptom | Root cause | Fix |
| --- | --- | --- | --- |
| 1 | Specialist never reacts to the coordinator's `@mention` | Telegram does not deliver one bot's messages to another bot by default. A plain `@username` mention from a bot is only delivered when the receiving bot is a group **admin** with **privacy mode off** and **Bot-to-Bot Communication Mode** on | BotFather: Bot-to-Bot mode ON + privacy OFF for every bot; promote all bots to admin |
| 2 | Coordinator answers a report as if it never sent a plan | Hermes default `group_sessions_per_user: true`: a report from a *different sender* (the specialist bot) opens a new session without the plan | `group_sessions_per_user: false` → one shared session per group |
| 3 | Second report interrupts the coordinator while it is processing the first | Default `busy_input_mode: interrupt` | `busy_input_mode: queue` |
| 4 | Coordinator could post a final answer after only one report | LLM ignores the "wait for all Tn" rule | Explicit `NO_REPLY` rule in SOUL.md (Hermes suppresses exact `NO_REPLY`); task ids make "all done" checkable |
| 5 | Agents stop answering after a few tests | OpenRouter free tier: 50 requests/day per key, shared by all three agents; one team request ≈ 15–30 model calls | Add $10 credit (1000/day) or move specialists to a local Ollama model |

## Limits that remain
* Only one human request at a time per group: two concurrent requests share the coordinator session and task ids `T1/T2` would collide.
* Coordinator trusts specialist output; a hallucinated source from the researcher is passed on.
* Agents only see messages addressed to them, so a human cannot "jump in" mid-flow without an @mention.
