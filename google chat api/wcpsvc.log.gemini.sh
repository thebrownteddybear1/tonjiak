#!/bin/bash
# --- CONFIG ---
API_KEY="AIzaSyDQZrG03fkcHYsY1n7wgUb4Jb38f_OJd0E"
MODEL="gemini-3-flash-preview"
LOG_FILE="/var/log/vmware/wcp/wcpsvc.log"

echo "-------------------------------------------------------"
echo "  WCP ZONAL ERROR ANALYZER (SENDING TO AI)"
echo "-------------------------------------------------------"

# 1. Extract the relevant log snippets
LOG_SNIPPET=$(tail -n 100 "$LOG_FILE" | grep -iE "error|failed|zonal|reconcile" | tr -d '\n' | tr '"' "'")

if [ -z "$LOG_SNIPPET" ]; then
    LOG_SNIPPET="No specific error patterns found in the last 100 lines."
fi

# 2. Prepare the JSON payload
JSON_DATA=$(jq -n \
    --arg logs "$LOG_SNIPPET" \
    --arg system "You are the Gemini 3 Flash VCF Lab Assistant. The user's Zonal Supervisor enablement is failing. Analyze these wcpsvc.log entries and provide the root cause and a fix." \
    '{contents: [{role: "user", parts: [{text: ($system + "\n\nLOG DATA: " + $logs)}]}]}')

# 3. Send to Gemini
RESPONSE=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}" \
    -H 'Content-Type: application/json' \
    --data-binary "$JSON_DATA")

echo "-------------------------------------------------------"
echo "  AI ANALYSIS RESULT:"
echo "-------------------------------------------------------"
echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text'
echo "-------------------------------------------------------"