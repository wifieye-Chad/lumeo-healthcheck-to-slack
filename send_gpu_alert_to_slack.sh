#!/bin/bash

# Load secrets
source /usr/local/etc/lumeo-slack.env

HOSTNAME=$(hostname)
TS=$(date "+%Y-%m-%d %H:%M:%S")

for i in $(nvidia-smi -L | nl -v 0 | awk '{print $1}'); do
  stats=($(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits -i $i | tr -d ',%' | awk '{print $1, $2, $3, $4}'))
  util=${stats[0]:-0}
  memused=${stats[1]:-0}
  memtot=${stats[2]:-1}
  temp=${stats[3]:-0}
  read -r fps lat <<< $(nvidia-smi -q -i $i | awk '/Average FPS/ && !seen++ {f=$4} /Average Latency/ && !done++ {print f, $4}')
  fps=${fps:-0}

  if [ "$memtot" -gt 0 ]; then
    mempct=$(( 100 * memused / memtot ))
  else
    mempct=0
  fi

  ALERT=0
  REASON=""
  [[ "$util" =~ ^[0-9]+$ ]] && [ "$util" -ge 80 ] && { ALERT=1; REASON="Utilization >= 80%"; }
  [[ "$temp" =~ ^[0-9]+$ ]] && [ "$temp" -ge 85 ] && { ALERT=1; REASON="Temperature >= 85C"; }
  [[ "$mempct" =~ ^[0-9]+$ ]] && [ "$mempct" -ge 90 ] && { ALERT=1; REASON="VRAM Usage >= 90%"; }
  [[ "$fps" =~ ^[0-9]+$ ]] && [[ "$util" =~ ^[0-9]+$ ]] && [ "$fps" -le 3 ] && [ "$util" -ge 65 ] && { ALERT=1; REASON="Low FPS <= 3 with Util >= 65%"; }

  if [ $ALERT -eq 1 ]; then
    TEXT="🚨 *GPU Alert* on \`$HOSTNAME\` (GPU$i)\n• Util: ${util}%\n• Temp: ${temp}°C\n• FPS: ${fps}\n• VRAM: ${mempct}%\n• Time: $TS\n*Reason*: $REASON\n\n🧠 *Reply in thread with* \`restart\` *(restarts lumeo container) or* \`reboot\` *(reboots the whole gateway)*"

    PAYLOAD=$(jq -nc --arg text "$TEXT" '{
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: $text
          }
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: { type: "plain_text", text: "Open Lumeo Console" },
              url: "https://console.lumeo.com/login"
            }
          ]
        }
      ]
    }')

    curl -s -X POST -H 'Content-type: application/json' \
      --data "$PAYLOAD" \
      "$SLACK_WEBHOOK_URL"
  fi
done
