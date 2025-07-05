#!/bin/bash

WEBHOOK_URL="https://hooks.slack.com/services/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"
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
  [[ "$util" =~ ^[0-9]+$ ]] && [ "$util" -le 5 ] && { ALERT=1; REASON="GPU Utilization <= 5%"; }

  CPU_USE=$(top -bn1 | awk '/Cpu\(s\)/ {print 100 - $8}' | cut -d. -f1)
  [[ "$CPU_USE" =~ ^[0-9]+$ ]] && [ "$CPU_USE" -le 5 ] && { ALERT=1; REASON="CPU Usage <= 5%"; }

  if [ $ALERT -eq 1 ]; then
    TEXT="ALERT on $HOSTNAME (GPU$i)\nUtil: ${util}%\nTemp: ${temp}°C\nFPS: ${fps}\nVRAM: ${mempct}%\nCPU: ${CPU_USE}%\nTime: $TS\nReason: $REASON"

    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\": \"$TEXT\"}" \
      "$WEBHOOK_URL"
  fi
done
