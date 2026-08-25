{ pkgs }:

pkgs.writers.writePython3Bin "ai-usage" {
  flakeIgnore = [ "E302" "E305" "E306" "E501" ];
} ''
  import json
  import os
  import subprocess
  import sys
  import urllib.request
  from datetime import datetime, timezone
  from pathlib import Path

  scanners = {
      "Claude Code": ["${pkgs.python3}/bin/python3", "${./ai-usage-scanners/claude.py}"],
      "Codex": ["${pkgs.python3}/bin/python3", "${./ai-usage-scanners/codex.py}"],
      "OpenCode Go": ["${pkgs.python3}/bin/python3", "${./ai-usage-scanners/opencode-go.py}"],
  }

  cache_path = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "ai-usage/providers.json"

  def read_cache(max_age_seconds=None):
      try:
          if max_age_seconds is not None and datetime.now().timestamp() - cache_path.stat().st_mtime > max_age_seconds:
              return None
          providers = json.loads(cache_path.read_text())
          return providers if isinstance(providers, list) else None
      except (OSError, ValueError):
          return None

  def write_cache(providers):
      cache_path.parent.mkdir(parents=True, exist_ok=True)
      temporary = cache_path.with_suffix(".tmp")
      temporary.write_text(json.dumps(providers))
      temporary.replace(cache_path)

  def run_scanner(name):
      try:
          result = subprocess.run(scanners[name], text=True, capture_output=True, timeout=25, check=True)
          return json.loads(result.stdout)
      except Exception as error:
          return {"usageStatusText": f"{name} unavailable: {error}", "rateLimitPercent": -1}

  def read_claude_limits():
      credentials = Path.home() / ".claude/.credentials.json"
      try:
          oauth = json.loads(credentials.read_text())["claudeAiOauth"]
          token = oauth["accessToken"]
          request = urllib.request.Request(
              "https://api.anthropic.com/api/oauth/usage",
              headers={
                  "Authorization": f"Bearer {token}",
                  "anthropic-beta": "oauth-2025-04-20",
                  "Accept": "application/json",
              },
          )
          with urllib.request.urlopen(request, timeout=10) as response:
              payload = json.load(response)
          weekly = payload.get("seven_day_oauth_apps") or payload.get("seven_day") or {}
          session = payload.get("five_hour") or {}
          def utilization(bucket):
              value = float(bucket.get("utilization", -1))
              return value / 100 if value > 1 else value
          return {
              "tierLabel": oauth.get("subscriptionType") or oauth.get("rateLimitTier") or "",
              "rateLimitPercent": utilization(session),
              "rateLimitLabel": "Session (5-hour)",
              "rateLimitResetAt": session.get("resets_at", ""),
              "secondaryRateLimitPercent": utilization(weekly),
              "secondaryRateLimitLabel": "Weekly (7-day)",
              "secondaryRateLimitResetAt": weekly.get("resets_at", ""),
          }
      except Exception as error:
          return {"usageStatusText": f"Claude limits unavailable: {error}", "rateLimitPercent": -1}

  def load_providers():
      claude = run_scanner("Claude Code")
      claude.update(read_claude_limits())
      return [("Claude Code", claude), ("Codex", run_scanner("Codex")), ("OpenCode Go", run_scanner("OpenCode Go"))]

  def percent(value):
      try:
          value = float(value)
          return value if value >= 0 else None
      except (TypeError, ValueError):
          return None

  def reset_text(value):
      if not value:
          return ""
      try:
          timestamp = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
          seconds = max(0, int((timestamp - datetime.now(timezone.utc)).total_seconds()))
          hours, seconds = divmod(seconds, 3600)
          minutes = seconds // 60
          return f" · resets in {hours}h {minutes}m" if hours else f" · resets in {minutes}m"
      except ValueError:
          return f" · resets {value}"

  def limit_rows(data):
      rows = []
      for prefix in ("rateLimit", "secondaryRateLimit", "tertiaryRateLimit"):
          used = percent(data.get(prefix + "Percent"))
          if used is None:
              continue
          label = data.get(prefix + "Label") or "Limit"
          rows.append(f"  {label}: {used:.0%} used · {1 - used:.0%} left" + reset_text(data.get(prefix + "ResetAt")))
      return rows

  def token_text(tokens):
      tokens = int(tokens or 0)
      return f"{tokens / 1000000:.1f}M" if tokens >= 1000000 else f"{tokens / 1000:.1f}K" if tokens >= 1000 else str(tokens)

  def details(providers):
      lines = []
      for name, data in providers:
          tier = data.get("tierLabel") or ""
          lines.append(name + (" · " + tier if tier else ""))
          rows = limit_rows(data)
          if rows:
              lines.extend(rows)
          else:
              lines.append("  " + (data.get("usageStatusText") or "No signed-in usage data"))
          lines.append(f"  Today: {token_text(data.get('todayTotalTokens'))} tokens · {data.get('todayPrompts', 0)} prompts")
          lines.append("")
      return "\n".join(lines).rstrip()

  def summary(providers):
      usage = [used for _, data in providers for used in (percent(data.get("rateLimitPercent")), percent(data.get("secondaryRateLimitPercent")), percent(data.get("tertiaryRateLimitPercent"))) if used is not None]
      text = f"AI {1 - max(usage):.0%} left" if usage else "AI —"
      return json.dumps({"text": text, "tooltip": details(providers), "percentage": int(max(usage, default=0) * 100)})

  mode = sys.argv[1] if len(sys.argv) > 1 else "status"
  # The bar refreshes this snapshot every five minutes.  Reading it on click
  # avoids waiting for the Codex RPC and the provider usage endpoints.
  providers = read_cache() if mode == "details" else None
  if providers is None:
      providers = load_providers()
      write_cache(providers)
  if mode == "details":
      print(details(providers))
  else:
      print(summary(providers))
''
