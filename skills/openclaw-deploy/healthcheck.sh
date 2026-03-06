#!/bin/bash
#
# OpenClaw Gateway Health Check
# Deploy to: ~/.openclaw/healthcheck.sh
# Crontab:   */5 * * * * /Users/<user>/.openclaw/healthcheck.sh
#
# Detects stuck feishu WebSocket (repeated reconnect with no healthy activity)
# and kills the process so launchctl can auto-restart it.

LOG_DIR="$HOME/.openclaw/logs"
HC_LOG="$LOG_DIR/healthcheck.log"
OC_LOG="/tmp/openclaw/openclaw-$(date -u +%Y-%m-%d).log"
FEISHU_URL="https://open.feishu.cn/open-apis/bot/v3/info"
RECONNECT_THRESHOLD=3
LOOKBACK_MINUTES=5

log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") $1" >> "$HC_LOG"
}

mkdir -p "$LOG_DIR"

# Rotate healthcheck log if > 1MB
if [ -f "$HC_LOG" ] && [ "$(stat -f%z "$HC_LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    mv "$HC_LOG" "$HC_LOG.old"
fi

PID=$(pgrep -f "openclaw-gateway" | head -1)
if [ -z "$PID" ]; then
    log "[WARN] openclaw-gateway not running, launchctl should auto-restart"
    exit 0
fi

if [ ! -f "$OC_LOG" ]; then
    log "[WARN] log file not found: $OC_LOG"
    exit 0
fi

CUTOFF=$(date -u -v-${LOOKBACK_MINUTES}M "+%Y-%m-%dT%H:%M")

RECENT_LINES=$(python3 -c "
import sys, json
cutoff = '$CUTOFF'
for line in open('$OC_LOG'):
    try:
        d = json.loads(line.strip())
        t = d.get('time','')
        if t >= cutoff:
            print(line.strip())
    except:
        pass
" 2>/dev/null)

if [ -z "$RECENT_LINES" ]; then
    log "[INFO] no recent log entries in last ${LOOKBACK_MINUTES}m, skipping"
    exit 0
fi

RECONNECT_COUNT=$(echo "$RECENT_LINES" | grep -c -E "reconnect|timeout.*exceeded|ECONNABORTED")
HEALTHY_COUNT=$(echo "$RECENT_LINES" | grep -c -E "lane dequeue|embedded run|event-dispatch.*ready|ws client ready")

if [ "$RECONNECT_COUNT" -ge "$RECONNECT_THRESHOLD" ] && [ "$HEALTHY_COUNT" -eq 0 ]; then
    log "[ALERT] detected stuck state: reconnect=$RECONNECT_COUNT healthy=$HEALTHY_COUNT in last ${LOOKBACK_MINUTES}m"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$FEISHU_URL" 2>/dev/null)

    if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" != "000" ]; then
        log "[ACTION] network OK (http=$HTTP_CODE), killing PID $PID to trigger launchctl restart"
        kill -9 "$PID"
        log "[ACTION] kill -9 sent to PID $PID, launchctl will auto-restart"
    else
        log "[WAIT] network unreachable (http=$HTTP_CODE), skipping restart"
    fi
else
    log "[OK] healthy: reconnect=$RECONNECT_COUNT healthy=$HEALTHY_COUNT"
fi
