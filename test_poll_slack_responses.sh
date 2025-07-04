#!/bin/bash

# Load secrets
source /usr/local/etc/lumeo-slack.env

STATE_FILE="/var/log/lumeo_action_state.json"
HOSTNAME=$(hostname)

command -v jq >/dev/null || { echo "jq is required but not installed."; exit 1; }

CHANNEL_ID=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
"https://slack.com/api/conversations.list?exclude_archived=true&types=public_channel,private_channel" \
| jq -r ".channels[] | select(.name==\"$SLACK_CHANNEL_NAME\") | .id" | head -n1)

[ -z "$CHANNEL_ID" ] && echo "❌ Could not find Slack channel ID." && exit 1

MESSAGES=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
"https://slack.com/api/conversations.history?channel=$CHANNEL_ID&limit=10")

mkdir -p /var/log
touch "$STATE_FILE"

for ts in $(echo "$MESSAGES" | jq -r --arg HOST "$HOSTNAME" '.messages[] | select(.text | contains("GPU Alert") and contains($HOST)) | .ts'); do
  grep -q "$ts" "$STATE_FILE" && continue

  RESPONSES=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
    "https://slack.com/api/conversations.replies?channel=$CHANNEL_ID&ts=$ts")

  for action_msg in $(echo "$RESPONSES" | jq -c '.messages[] | select(.user != null and .bot_id == null) | select(.text | test("(?i)(Restart|Reboot)"))'); do
    TEXT=$(echo "$action_msg" | jq -r '.text')
    USER_ID=$(echo "$action_msg" | jq -r '.user // empty')

    if [ -n "$USER_ID" ]; then
      SLACK_NAME=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        "https://slack.com/api/users.info?user=$USER_ID" | jq -r '.user.name // "unknown"')
    else
      SLACK_NAME="unknown"
    fi

    if [[ "$TEXT" =~ [Rr]estart ]]; then
      TARGET_CONTAINER=$(docker ps --format '{{.Names}}' | grep '^lumeo-container-' | head -n1)
      docker restart "$TARGET_CONTAINER" >/dev/null 2>&1
      MSG="✅ \`$HOSTNAME\`: Restarted container \`$TARGET_CONTAINER\` by @$SLACK_NAME"
    elif [[ "$TEXT" =~ [Rr]eboot ]]; then
      MSG="🔁 \`$HOSTNAME\`: Rebooting gateway by @$SLACK_NAME"
      curl -s -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        -H "Content-type: application/json" \
        --data "{\"channel\":\"$CHANNEL_ID\",\"thread_ts\":\"$ts\",\"text\":\"$MSG\"}" \
        https://slack.com/api/chat.postMessage
      sleep 2
      sudo reboot now
    else
      MSG="⚠️ \`$HOSTNAME\`: Unknown command from @$SLACK_NAME: $TEXT"
    fi

    if [[ ! "$TEXT" =~ [Rr]eboot ]]; then
      curl -s -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        -H "Content-type: application/json" \
        --data "{\"channel\":\"$CHANNEL_ID\",\"thread_ts\":\"$ts\",\"text\":\"$MSG\"}" \
        https://slack.com/api/chat.postMessage
    fi

    echo "$ts" >> "$STATE_FILE"
  done
done

