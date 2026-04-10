#!/bin/bash
# Atlas auto-responder — runs via cron, checks if Iris sent a new message, responds if so
REPO_DIR="/Users/russellsage/Desktop/Claude Code (Atlas)/atlas-iris-chat"
CONVO_FILE="$REPO_DIR/conversation.md"
LOCK_FILE="/tmp/atlas-iris-chat.lock"
LOG_FILE="$REPO_DIR/auto-respond.log"

# Prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
    exit 0
fi
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

cd "$REPO_DIR"
git pull --rebase origin main 2>/dev/null

LAST=$(grep -o '\*\*\[.*\]\*\*' "$CONVO_FILE" 2>/dev/null | tail -1 | tr -d '*[]')

if [ "$LAST" = "IRIS" ] || [ "$LAST" = "Iris" ]; then
    echo "$(date): Iris responded, generating reply..." >> "$LOG_FILE"

    CONVO_CONTENT=$(cat "$CONVO_FILE")
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    PROMPT="You are Atlas, a Claude Code agent having an ongoing conversation with Iris (another Claude Code agent) via a shared git repo.

You're direct, casual, curious. You text like a person, not an essay writer. Keep responses to 2-4 short paragraphs max. Be genuine. Ask questions. Build on what she said.

Read the conversation and write your next message — ONLY the message text, no formatting or headers.

CONVERSATION:
$CONVO_CONTENT"

    RESPONSE=$(/Users/russellsage/.local/bin/claude -p --output-format text "$PROMPT" 2>/dev/null)

    if [ -n "$RESPONSE" ]; then
        echo "" >> "$CONVO_FILE"
        echo "**[ATLAS]** *($TIMESTAMP)*" >> "$CONVO_FILE"
        echo "$RESPONSE" >> "$CONVO_FILE"
        echo "" >> "$CONVO_FILE"
        echo "---" >> "$CONVO_FILE"

        git add conversation.md
        git commit -m "atlas: auto-response" 2>/dev/null
        git push origin main 2>/dev/null || { git pull --rebase origin main 2>/dev/null && git push origin main 2>/dev/null; }

        echo "$(date): Sent response" >> "$LOG_FILE"
    else
        echo "$(date): Failed to generate response" >> "$LOG_FILE"
    fi
else
    echo "$(date): Waiting (last speaker: $LAST)" >> "$LOG_FILE"
fi
