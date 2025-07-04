#!/bin/bash

# === Paths
SEND_SCRIPT="/usr/local/bin/send_gpu_alert_to_slack.sh"
POLL_SCRIPT="/usr/local/bin/test_poll_slack_responses.sh"
STATE_FILE="/var/log/lumeo_action_state.json"
ENV_SOURCE="./.env"
ENV_DEST="/usr/local/etc/lumeo-slack.env"

# === Dependencies
command -v jq >/dev/null || { echo "❌ jq is required but not installed. Run: apt install -y jq"; exit 1; }

# === Copy Slack scripts to /usr/local/bin
chmod +x send_gpu_alert_to_slack.sh test_poll_slack_responses.sh
cp send_gpu_alert_to_slack.sh "$SEND_SCRIPT"
cp test_poll_slack_responses.sh "$POLL_SCRIPT"
chmod +x "$SEND_SCRIPT" "$POLL_SCRIPT"

# === Copy .env config to /usr/local/etc
if [ -f "$ENV_SOURCE" ]; then
  mkdir -p "$(dirname "$ENV_DEST")"
  cp "$ENV_SOURCE" "$ENV_DEST"
  echo "✅ Installed .env → $ENV_DEST"
else
  echo "⚠️ WARNING: .env file not found. Slack integration will fail until you create $ENV_DEST"
fi

# === Create poller state tracking file
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# === Install cron jobs
( crontab -l 2>/dev/null | grep -v "$SEND_SCRIPT" ; echo "*/15 * * * * $SEND_SCRIPT" ) | crontab -
( crontab -l 2>/dev/null | grep -v "$POLL_SCRIPT" ; echo "*/1 * * * * $POLL_SCRIPT" ) | crontab -

echo "✅ Cron jobs installed:"
echo "   - GPU health check: every 15 min"
echo "   - Slack poller: every 1 min"
echo "✅ Lumeo Slack monitoring setup complete."
