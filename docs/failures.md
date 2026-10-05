# Failures and limits found while building

| # | Symptom | Root cause | Fix |
| --- | --- | --- | --- |
| 1 | Specialist never reacts to the coordinator's `@mention` | Telegram does not deliver one bot's messages to another bot by default. A plain `@username` mention from a bot is only delivered when the receiving bot is a group **admin** with **privacy mode off** and **Bot-to-Bot Communication Mode** on | BotFather: Bot-to-Bot mode ON + privacy OFF for every bot; promote all bots to admin |
| 2 | Coordinator answers a report as if it never sent a plan | Hermes default `group_sessions_per_user: true`: a report from a *different sender* (the specialist bot) opens a new session without the plan | `group_sessions_per_user: false` → one shared session per group |
| 3 | Second report interrupts the coordinator while it is processing the first | Default `busy_input_mode: interrupt` | `busy_input_mode: queue` |
| 4 | First live test: coordinator replied to the first report with an error-like text instead of staying silent | SOUL told it to answer `NO_REPLY`, but Hermes rejects silence markers on chat turns (`silence marker rejected on a user turn`) and sends a fallback text | Wait signal is now a one-line status with no @mentions (`⏳ T1 received, waiting for T2`); task ids make "all done" checkable |
| 5 | Agents stop answering after a few tests | OpenRouter free tier: 50 requests/day per account (all free models together), shared by all three agents; one team request ≈ 8–15 model calls (measured: second live run) | Switched all agents to `gemini-3.8-flash` on the Google AI Studio free tier (alternatives: $10 OpenRouter credit, or a local Ollama model) |
| 6 | First live test: coder never reported T2 | (a) the default *smart* approval asks a guardian LLM about each command; with the free model it hit the token limit and escalated to a human button; (b) the model then used the `clarify` tool and waited for an answer in the group for 8+ minutes | Coder: `approvals.mode: off` + deny-list of dangerous patterns; `clarify` toolset disabled for Telegram on all agents; SOUL: "never ask clarifying questions" |
| 7 | Coordinator asked the human which language to use (button) before dispatching | Same `clarify` tool | Same fix |
| 8 | Second live test: coordinator still answered the T1 report with `NO_REPLY` although `SOUL.md` had been fixed | Hermes snapshots the system prompt (SOUL) per session; the group session started before the fix kept the old prompt | Reset the group session (`/new` in the group) after every SOUL change |
| 9 | Coder delivered pure-Python matrix code instead of NumPy | `execute_code` runs in Hermes' own venv (`code_execution.mode: project`), which had no NumPy; the model fell back to plain Python after `ModuleNotFoundError` | `uv pip install numpy` into `~/.hermes/hermes-agent/venv`; README setup step added |

## Limits that remain
* Only one human request at a time per group: two concurrent requests share the coordinator session and task ids `T1/T2` would collide.
* Coordinator trusts specialist output; a hallucinated source from the researcher is passed on.
* Agents only see messages addressed to them, so a human cannot "jump in" mid-flow without an @mention.
