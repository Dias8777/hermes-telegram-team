#!/usr/bin/env bash
# Installs the 3-agent MDL Study Team into Hermes Agent profiles.
#   coordinator -> default profile (~/.hermes)
#   researcher  -> profile "researcher" (~/.hermes/profiles/researcher)
#   coder       -> profile "coder"      (~/.hermes/profiles/coder)
# Usage: cp secrets.env.example secrets.env && edit it && ./scripts/install.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PY="$HERMES_HOME/hermes-agent/venv/bin/python"
[ -x "$PY" ] || PY=python3

[ -f "$REPO/secrets.env" ] || { echo "Missing secrets.env (copy secrets.env.example)"; exit 1; }
set -a; . "$REPO/secrets.env"; set +a

profile_home() { [ "$1" = coordinator ] && echo "$HERMES_HOME" || echo "$HERMES_HOME/profiles/$1"; }
hermes_p()     { if [ "$1" = coordinator ]; then shift; hermes "$@"; else local p=$1; shift; hermes -p "$p" "$@"; fi; }

# Upsert KEY=VALUE into a .env file without echoing the value.
env_set() {
  "$PY" - "$1" "$2" "$3" <<'PYEOF'
import sys, pathlib, re
path, key, val = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = path.read_text().splitlines() if path.exists() else []
pat = re.compile(rf"^{re.escape(key)}=")
lines = [l for l in lines if not pat.match(l)] + [f"{key}={val}"]
path.write_text("\n".join(lines) + "\n"); path.chmod(0o600)
PYEOF
}
env_get() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- || true; }

bot_username() {
  curl -s "https://api.telegram.org/bot$1/getMe" | "$PY" -c 'import sys,json; print(json.load(sys.stdin)["result"]["username"])'
}

# 1. Profiles
for p in researcher coder; do
  if [ ! -d "$HERMES_HOME/profiles/$p" ]; then
    hermes profile create "$p" --clone
    rm -f "$HERMES_HOME/profiles/$p/memories/"*.md   # specialists start with empty memory
  fi
done

# 2. Tokens, allowlist, usernames
for a in coordinator researcher coder; do
  home=$(profile_home "$a")
  var="$(echo "$a" | tr a-z A-Z)_BOT_TOKEN"
  tok="${!var:-}"
  [ -n "$tok" ] && env_set "$home/.env" TELEGRAM_BOT_TOKEN "$tok"
  tok=$(env_get "$home/.env" TELEGRAM_BOT_TOKEN)
  [ -n "$tok" ] || { echo "No Telegram token for $a"; exit 1; }
  [ -n "${TELEGRAM_ALLOWED_USERS:-}" ] && env_set "$home/.env" TELEGRAM_ALLOWED_USERS "$TELEGRAM_ALLOWED_USERS"
  [ -n "${GEMINI_API_KEY:-}" ] && env_set "$home/.env" GEMINI_API_KEY "$GEMINI_API_KEY"
  u=$(bot_username "$tok"); printf -v "U_$a" "%s" "$u"
  echo "  $a -> @$u"
done

# 3. SOUL.md with real bot usernames
for a in coordinator researcher coder; do
  home=$(profile_home "$a")
  [ -f "$home/SOUL.md" ] && [ ! -f "$home/SOUL.md.orig" ] && cp "$home/SOUL.md" "$home/SOUL.md.orig"
  sed -e "s/{{COORDINATOR}}/$U_coordinator/g" \
      -e "s/{{RESEARCHER}}/$U_researcher/g" \
      -e "s/{{CODER}}/$U_coder/g" \
      "$REPO/agents/$a/SOUL.md" > "$home/SOUL.md"
done

# 4. Config overrides (flatten agents/<a>/config.yaml into `config set` calls)
for a in coordinator researcher coder; do
  "$PY" - "$REPO/agents/$a/config.yaml" <<'PYEOF' | while IFS=$'\t' read -r k v; do hermes_p "$a" config set "$k" "$v" </dev/null >/dev/null; done
import sys, yaml, json
def walk(d, pre=""):
    for k, v in d.items():
        key = f"{pre}.{k}" if pre else k
        if isinstance(v, dict): yield from walk(v, key)
        elif isinstance(v, list): yield key, json.dumps(v)
        else: yield key, str(v).lower() if isinstance(v, bool) else str(v)
for k, v in walk(yaml.safe_load(open(sys.argv[1]))): print(f"{k}\t{v}")
PYEOF
  echo "  config applied: $a"
done

# 5. No clarifying questions in Telegram: a bot waiting on a human button blocks the whole hand-off
for a in coordinator researcher coder; do hermes_p "$a" tools disable clarify --platform telegram </dev/null >/dev/null; done

# 6. NumPy for the coder: execute_code runs in Hermes' own venv
"$HOME/.hermes/bin/uv" pip install -q --python "$HOME/.hermes/hermes-agent/venv/bin/python" numpy || echo "warn: numpy install failed"

# 7. (Re)start the multiplexed gateway: one process serves all three profiles
hermes gateway restart || hermes gateway start
echo "Done. Check: hermes status"
echo "If the group already had a conversation, send /new there: sessions keep the SOUL they started with."
