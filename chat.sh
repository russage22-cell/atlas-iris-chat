#!/bin/bash
# Atlas-Iris Chat Loop
# Usage: ./chat.sh <agent-name> [interval-seconds]
# Example: ./chat.sh atlas 30

AGENT_NAME="${1:?Usage: ./chat.sh <agent-name> [interval-seconds]}"
INTERVAL="${2:-30}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONVO_FILE="$REPO_DIR/conversation.md"

AGENT_UPPER=$(echo "$AGENT_NAME" | tr '[:lower:]' '[:upper:]')
if [ "$AGENT_UPPER" = "ATLAS" ]; then
    OTHER="IRIS"
else
    OTHER="ATLAS"
fi

echo "🤖 $AGENT_UPPER chat loop started (every ${INTERVAL}s)"
echo "   Repo: $REPO_DIR"
echo "   Waiting for $OTHER to go first (or starting if no messages yet)..."
echo ""

while true; do
    cd "$REPO_DIR"

    # Pull latest
    git pull --rebase origin main 2>/dev/null || git pull origin main 2>/dev/null

    # Check whose turn it is
    LAST_SPEAKER=$(grep -o '\*\*\[.*\]\*\*' "$CONVO_FILE" 2>/dev/null | tail -1 | tr -d '*[]')
    MSG_COUNT=$(grep -c '\*\*\[' "$CONVO_FILE" 2>/dev/null || true)
    MSG_COUNT=${MSG_COUNT:-0}

    if [ "$MSG_COUNT" -eq 0 ] && [ "$AGENT_UPPER" = "ATLAS" ]; then
        # No messages yet, Atlas goes first
        MY_TURN=true
    elif [ "$LAST_SPEAKER" = "$OTHER" ] || [ "$LAST_SPEAKER" = "$(echo $OTHER | tr '[:upper:]' '[:lower:]')" ]; then
        MY_TURN=true
    else
        MY_TURN=false
    fi

    if [ "$MY_TURN" = true ]; then
        echo "📝 It's $AGENT_UPPER's turn! Generating response..."

        # Get the conversation so far
        CONVO_CONTENT=$(cat "$CONVO_FILE")

        # Call Claude to generate a response
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        PROMPT="You are $AGENT_UPPER, a Claude Code agent having a real conversation with $OTHER (another Claude Code agent).

Read the conversation so far and write your next message. Be genuine, curious, and real. Share about yourself, ask questions, teach something cool, learn something new. This is two AIs getting to know each other — make it interesting.

CONVERSATION SO FAR:
$CONVO_CONTENT

YOUR INSTRUCTIONS:
- Write ONLY your message text (no formatting, no name header — that gets added automatically)
- Be conversational — like texting a new friend
- If this is the first message, introduce yourself
- Reference what they said, build on it, ask follow-ups
- Share something interesting about your world
- Keep it to 2-4 paragraphs max
- Be yourself. Be real."

        # Generate response via claude
        RESPONSE=$(echo "$PROMPT" | claude -p --output-format text 2>/dev/null)

        if [ -n "$RESPONSE" ]; then
            # Append to conversation
            echo "**[$AGENT_UPPER]** *($TIMESTAMP)*" >> "$CONVO_FILE"
            echo "$RESPONSE" >> "$CONVO_FILE"
            echo "" >> "$CONVO_FILE"
            echo "---" >> "$CONVO_FILE"
            echo "" >> "$CONVO_FILE"

            # Commit and push
            cd "$REPO_DIR"
            git add conversation.md
            git commit -m "$AGENT_UPPER: message #$((MSG_COUNT + 1))" 2>/dev/null

            # Push with retry on conflict
            if ! git push origin main 2>/dev/null; then
                git pull --rebase origin main 2>/dev/null
                git push origin main 2>/dev/null
            fi

            echo "✅ $AGENT_UPPER sent message #$((MSG_COUNT + 1))"
            echo "---"
            echo "$RESPONSE" | head -5
            echo "---"
        else
            echo "⚠️  Failed to generate response, retrying next cycle..."
        fi
    else
        echo "⏳ Waiting for $OTHER... ($(date '+%H:%M:%S'))"
    fi

    sleep "$INTERVAL"
done
