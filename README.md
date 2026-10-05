# MDL Study Team — three Hermes agents in one Telegram group

Assignment 1, Modern Deep Learning (AITU). A small team of AI agents, each a separate
[Hermes Agent](https://github.com/NousResearch/hermes-agent) profile with its own Telegram bot,
that cooperate in a group chat by **@mentioning each other**.

Use case: a **study helper for the Deep Learning course**. A student asks a question like
*"Explain causal self-attention and show it in code"*; the team returns an explanation with
sources **and** runnable code with its real output.

## The team

| Agent | Hermes profile | Telegram bot | Job | Main tools |
| --- | --- | --- | --- | --- |
| Coordinator | `default` (`~/.hermes`) | `@mdl_dias_aitu_bot` | Splits the request, hands off subtasks, waits for all reports, writes the final answer | none needed (planning only) |
| Researcher | `researcher` | `@<researcher_bot>` | Finds 2–4 sources and writes a short sourced explanation | `web_search`, `web_extract` |
| Coder | `coder` | `@<coder_bot>` | Writes a small NumPy script, **runs it**, reports code + real output | `execute_code`, `terminal` |

All three run inside **one multiplexed Hermes gateway process** (Hermes serves every profile
from one process, each with its own bot token, `.env`, `SOUL.md`, memory and sessions).

## Message flow

```
Human:        @mdl_dias_aitu_bot explain causal self-attention and show it in code
Coordinator:  📋 Plan: causal self-attention — explanation + demo
              @researcher_bot [T1] Explain causal (masked) self-attention ... cite sources
              @coder_bot [T2] Implement causal scaled dot-product attention in NumPy ...
Researcher:   @mdl_dias_aitu_bot [T1 DONE] <explanation + links>
Coordinator:  ⏳ T1 received, waiting for T2.   (status line, no mentions -> wakes nobody)
Coder:        @mdl_dias_aitu_bot [T2 DONE] <code + real output>
Coordinator:  ✅ Final answer ... (no bot mentions -> conversation ends)
```

### How hand-off and termination work
* **Hand-off** = an @mention of the specialist at the start of a line, with a task id `[Tn]`.
* **Report** = specialist @mentions the coordinator once with `[Tn DONE]` / `[Tn FAILED]`.
* **Coordinator knows it is finished** when every `Tn` from its last plan has a report in the shared
  group session (`group_sessions_per_user: false`). Until then it posts a one-line status with **no
  @mentions** (Hermes refuses a silent `NO_REPLY` on a chat turn), so no bot is woken.
* **No infinite loops**, four layers:
  1. Protocol: the final answer never mentions a bot; specialists never mention each other.
  2. `bots_require_mention: true` — a bot's quote-reply alone does not wake another bot, only an explicit @mention.
  3. `exclusive_bot_mentions: true` — a message addressed to other bots is ignored.
  4. Hermes `bot_loop_guard` — more than 12 bot messages in a chat in 5 min → bot messages dropped for 10 min.

## Repository layout

```
agents/
  coordinator/  SOUL.md  config.yaml  .env.example
  researcher/   SOUL.md  config.yaml  .env.example
  coder/        SOUL.md  config.yaml  .env.example
scripts/install.sh      # creates profiles, renders SOUL.md with bot usernames, applies config, restarts gateway
secrets.env.example     # template for tokens (real secrets.env is git-ignored)
docs/                   # demo transcript / screenshots
```

`SOUL.md` files use `{{COORDINATOR}}`, `{{RESEARCHER}}`, `{{CODER}}` placeholders; `install.sh`
replaces them with the real bot usernames (read via Telegram `getMe`).

## Setup

### 1. Hermes
```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
hermes setup        # choose OpenRouter, paste OPENROUTER_API_KEY
```

### 2. Telegram bots (in @BotFather)
Create one bot per agent (`/newbot`). For **each** bot:
1. **Bot-to-Bot Communication Mode → ON** (BotFather Mini App → My bots → bot → Bot Settings).
   Without it Telegram never delivers one bot's messages to another.
2. **Group Privacy → OFF** (`/setprivacy` → Disable).
3. Create a group, add the three bots, and **promote all three to admins**. Telegram only delivers
   another bot's plain @mention to an admin bot with privacy off (otherwise only `/cmd@bot` or replies).
   If you changed privacy after adding a bot, remove and re-add it.

### 3. Install the team
```bash
cp secrets.env.example secrets.env   # fill in tokens + your Telegram user id
./scripts/install.sh
hermes status                        # should list default, researcher, coder as served
```

### 4. Try it
In the group: `@mdl_dias_aitu_bot Explain causal self-attention and show it in NumPy code`.

## Models
All agents use `nvidia/nemotron-3-super-120b-a12b:free` via OpenRouter: free, 120B MoE
(12B active), reliable tool calling. Limitation: OpenRouter's free tier allows **50 requests/day per
key** (shared by all three agents); one team request costs roughly 15–30 model calls. With $10 of
credit the limit becomes 1000/day. The model is set per profile, so e.g. the coordinator could use a
stronger model and the specialists a cheaper one.

## Memory
Each profile has its own memory (`<profile home>/memories/MEMORY.md`, `USER.md`) and its own
session database (`state.db`). Nothing is shared between agents except what is written in the
Telegram group. The coordinator keeps the course-TA user profile from the original MDL-TA bot;
the specialists start empty.

## Known limitations / failure modes
See `docs/failures.md`.
