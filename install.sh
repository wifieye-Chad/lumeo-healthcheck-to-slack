#!/bin/bash

# === Paths
SEND_SCRIPT="/usr/local/bin/send_gpu_alert_to_slack.sh"
POLL_SCRIPT="/usr/local/bin/test_poll_slack_responses.sh"
STATE_FILE="/var/log/lumeo_action_state.json"

# === Make sure dependencies exist
command -v jq >/dev/null || { echo "jq is required but not installed. Run: apt install -y jq"; exit 1; }

# === Copy scripts to system paths
chmod +x send_gpu_alert_to_slack.sh test_poll_slack_responses.sh
cp send_gpu_alert_to_slack.sh "$SEND_SCRIPT"
cp test_poll_slack_responses.sh "$POLL_SCRIPT"
chmod +x "$SEND_SCRIPT" "$POLL_SCRIPT"

# === Create log directory
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# === Install into crontab
( crontab -l 2>/dev/null | grep -v "$SEND_SCRIPT" ; echo "*/15 * * * * $SEND_SCRIPT" ) | crontab -
( crontab -l 2>/dev/null | grep -v "$POLL_SCRIPT" ; echo "*/1 * * * * $POLL_SCRIPT" ) | crontab -

echo "✅ Lumeo GPU + Slack monitoring installed and scheduled."
