#!/bin/bash

SEND_SCRIPT="/usr/local/bin/send_gpu_alert_to_slack.sh"
POLL_SCRIPT="/usr/local/bin/test_poll_slack_responses.sh"
STATE_FILE="/var/log/lumeo_action_state.json"
ENV_SOURCE="./.env"
ENV_DEST="/usr/local/etc/lumeo-slack.env"

command -v jq >/dev/null || { echo "❌ jq not installed. Run: apt install -y jq"; exit 1; }

# Ensure Unix line endings
sed -i 's/\r$//' send_gpu_alert_to_slack.sh
sed -i 's/\r$//' test_poll_slack_responses.sh

chmod +x send_gpu_alert_to_slack.sh test_poll_slack_responses.sh
cp send_gpu_alert_to_slack.sh "$SEND_SCRIPT"
cp test_poll_slack_responses.sh "$POLL_SCRIPT"
chmod +x "$SEND_SCRIPT" "$POLL_SCRIPT"

if [ -f "$ENV_SOURCE" ]; then
  mkdir -p "$(dirname "$ENV_DEST")"
  cp "$ENV_SOURCE" "$ENV_DEST"
  echo "✅ Installed .env to $ENV_DEST"
else
  echo "⚠️ No .env file found in repo. Slack alerts will fail."
fi

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

( crontab -l 2>/dev/null | grep -v "$SEND_SCRIPT" ; echo "*/15 * * * * $SEND_SCRIPT" ) | crontab -
( crontab -l 2>/dev/null | grep -v "$POLL_SCRIPT" ; echo "*/1 * * * * $POLL_SCRIPT" ) | crontab -

echo "✅ Lumeo Slack monitoring installed and scheduled."
