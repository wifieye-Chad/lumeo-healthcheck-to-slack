#!/bin/bash

SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"
GATEWAY_ID="f925774a-0fa4-423b-a269-47d7a7061ec5"
LUMEO_URL="https://console.lumeo.com/login"
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

  CPU_USE=$(top -bn1 | awk '/Cpu\(s\)/ {print 100 - $8}' | cut -d. -f1)

  ALERT=0
  REASON=""

  [[ "$util" =~ ^[0-9]+$ ]] && [ "$util" -ge 80 ] && { ALERT=1; REASON="Utilization >= 80%"; }
  [[ "$temp" =~ ^[0-9]+$ ]] && [ "$temp" -ge 85 ] && { ALERT=1; REASON="Temperature >= 85C"; }
  [[ "$mempct" =~ ^[0-9]+$ ]] && [ "$mempct" -ge 90 ] && { ALERT=1; REASON="VRAM Usage >= 90%"; }
  [[ "$fps" =~ ^[0-9]+$ ]] && [[ "$util" =~ ^[0-9]+$ ]] && [ "$fps" -le 3 ] && [ "$util" -ge 65 ] && { ALERT=1; REASON="Low FPS <= 3 with Util >= 65%"; }

  [[ "$util" =~ ^[0-9]+$ ]] && [ "$util" -le 5 ] && { ALERT=1; REASON="GPU Utilization <= 5%"; }
  [[ "$CPU_USE" =~ ^[0-9]+$ ]] && [ "$CPU_USE" -le 5 ] && { ALERT=1; REASON="CPU Usage <= 5%"; }

  if [ "$ALERT" -eq 1 ]; then
    TEXT="🚨 *GPU Alert* on \`$HOSTNAME\` (GPU$i)\n• Util: ${util}%\n• Temp: ${temp}°C\n• FPS: ${fps}\n• VRAM: ${mempct}%\n• CPU: ${CPU_USE}%\n• Time: $TS\n*Reason*: $REASON"

    read -r -d '' PAYLOAD << EOM
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "$TEXT"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {
            "type": "plain_text",
            "text": "Open Lumeo Console"
          },
          "url": "$LUMEO_URL"
        }
      ]
    }
  ]
}
EOM

    curl -s -X POST -H 'Content-type: application/json' \
      --data "$PAYLOAD" \
      "$SLACK_WEBHOOK_URL"
  fi
done
