#!/bin/bash

LOG="/home/eink_dipu/inkypi_schedule/inky_refresh.log"

tail -n 100 $LOG > $LOG.tmp 2>/dev/null && mv $LOG.tmp $LOG

echo "========================================" >> $LOG
echo "WAKE UP    : $(date '+%Y-%m-%d %H:%M:%S')" >> $LOG

for i in $(seq 1 30); do
    if curl -s http://localhost:80 > /dev/null 2>&1; then
        echo "STATUS     : InkyPi ready after ${i}s" >> $LOG
        break
    fi
    sleep 1
done

echo "ACTION     : Triggering refresh at $(date '+%H:%M:%S')" >> $LOG
REFRESH_RESULT=$(curl -s -X POST http://localhost:80/display_plugin_instance \
  -H "Content-Type: application/json" \
  -d '{"playlist_name": "PhotoWall", "plugin_id": "image_album", "plugin_instance": "Dhruv Album"}')
echo "REFRESH    : $REFRESH_RESULT" >> $LOG

sleep 75

echo "STATUS     : eInk done at $(date '+%H:%M:%S')" >> $LOG
BATTERY=$(echo "get battery" | nc -q 0 127.0.0.1 8423)
echo "BATTERY    : $BATTERY" >> $LOG

WAKE_TIMES=("7 0" "10 0" "13 0" "16 0" "19 0")
CURRENT_HOUR=$(date +%-H)
CURRENT_MINUTE=$(date +%-M)
NEXT_WAKE=""

for T in "${WAKE_TIMES[@]}"; do
    T_HOUR=$(echo $T | cut -d' ' -f1)
    T_MIN=$(echo $T | cut -d' ' -f2)
    if [ "$T_HOUR" -gt "$CURRENT_HOUR" ] || \
       ([ "$T_HOUR" -eq "$CURRENT_HOUR" ] && [ "$T_MIN" -gt "$CURRENT_MINUTE" ]); then
        NEXT_WAKE=$T
        break
    fi
done

if [ -z "$NEXT_WAKE" ]; then
    NEXT_DATETIME=$(date -d "tomorrow 07:00:00" --iso-8601=seconds)
    echo "STATUS     : Last cycle. Next wake tomorrow 7am" >> $LOG
else
    NEXT_HOUR=$(echo $NEXT_WAKE | cut -d' ' -f1)
    NEXT_MIN=$(echo $NEXT_WAKE | cut -d' ' -f2)
    NEXT_DATETIME=$(date -d "today ${NEXT_HOUR}:${NEXT_MIN}:00" --iso-8601=seconds)
    echo "STATUS     : Next wake at $NEXT_DATETIME" >> $LOG
fi

RTC_RESULT=$(echo "rtc_alarm_set $NEXT_DATETIME 127" | nc -q 0 127.0.0.1 8423)
echo "RTC        : $RTC_RESULT" >> $LOG
sleep 2

RTC_CONFIRM=$(echo "get rtc_alarm_time" | nc -q 0 127.0.0.1 8423)
echo "RTC CONF   : $RTC_CONFIRM" >> $LOG

echo "ACTION     : Shutdown at $(date '+%H:%M:%S')" >> $LOG
echo "========================================" >> $LOG
sleep 2
curl -s -X POST http://localhost:80/shutdown \
  -H "Content-Type: application/json" \
  -d '{}'
