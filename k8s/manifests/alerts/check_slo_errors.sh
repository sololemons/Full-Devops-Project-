#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Missing environment argument."
    echo "Env Usage: $0 <environment> (e.g., staging, production)"
    exit 1
fi

ENV=$1
NAMESPACE="kijani-${ENV}" 
APP_LABEL="app=kk-payments" 
OUTPUT_FILE="monitoring_summary_${ENV}.txt" 

echo "Gathering structured logs for $APP_LABEL in namespace $NAMESPACE for the last 2 minutes..."

LOGS=$(kubectl logs -n $NAMESPACE -l $APP_LABEL --since=2m 2>/dev/null)

if [ -z "$LOGS" ]; then
    echo "No logs found in the last 2 minutes for $NAMESPACE. System is idle." > $OUTPUT_FILE
    cat $OUTPUT_FILE
    exit 0
fi

TOTAL_REQUESTS=$(echo "$LOGS" | grep -E -c "202[0-9]|INFO|HTTP|GET|POST|\"level\"|\{")

if [ "$TOTAL_REQUESTS" -eq 0 ]; then
    TOTAL_REQUESTS=1
fi

ERROR_REQUESTS=$(echo "$LOGS" | grep -E -i '"level"(\s*):(\s*)"error"|"status"(\s*):(\s*)500|ERROR|NoSuchBucket|AccessDenied|httpStatusCode:\s*[45][0-9][0-9]' | wc -l)

if [ "$ERROR_REQUESTS" -gt "$TOTAL_REQUESTS" ]; then
    ERROR_REQUESTS=$TOTAL_REQUESTS
fi

ERROR_RATE=$(awk "BEGIN { printf \"%.2f\", ($ERROR_REQUESTS/$TOTAL_REQUESTS)*100 }")

echo "--- kk-payments SLO Monitoring Report ($NAMESPACE) ---" > $OUTPUT_FILE
echo "Timestamp: $(date)" >> $OUTPUT_FILE
echo "Evaluation Window: Last 2 minutes" >> $OUTPUT_FILE
echo "Total Requests/Events: $TOTAL_REQUESTS" >> $OUTPUT_FILE
echo "Error Count: $ERROR_REQUESTS" >> $OUTPUT_FILE
echo "Current Error Rate: $ERROR_RATE%" >> $OUTPUT_FILE
echo "------------------------------------------------------" >> $OUTPUT_FILE

IS_ALERT=$(awk "BEGIN { if ($ERROR_RATE > 5.0) print 1; else print 0 }")

if [ "$IS_ALERT" -eq 1 ]; then
    echo "STATUS: ALERT  - Error rate exceeds 5% SLO threshold!" >> $OUTPUT_FILE
else
    echo "STATUS: HEALTHY - Error rate is within acceptable parameters." >> $OUTPUT_FILE
fi

echo "SLO Report written to $OUTPUT_FILE:"
cat $OUTPUT_FILE
