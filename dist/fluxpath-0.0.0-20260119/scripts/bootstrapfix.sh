#!/bin/bash
set -e

TARGET="./scripts/bootstrap.sh"

if [ ! -f "$TARGET" ]; then
  echo "bootstrap.sh not found at $TARGET"
  exit 1
fi

echo "Scanning $TARGET for unterminated heredocs..."

# Detect heredoc starts
STARTS=$(grep -n "cat << '" "$TARGET" | sed "s/:.*//")

# Detect heredoc ends
ENDS=$(grep -n "^EOF" "$TARGET" | sed "s/:.*//")

# Convert to arrays
mapfile -t START_LINES <<< "$STARTS"
mapfile -t END_LINES <<< "$ENDS"

# If counts match, nothing to fix
if [ "${#START_LINES[@]}" -eq "${#END_LINES[@]}" ]; then
  echo "No unterminated heredocs detected."
  exit 0
fi

echo "Unterminated heredoc detected. Attempting repair..."

# Find last heredoc start
LAST_START=${START_LINES[-1]}

# Extract the terminator name
TERMINATOR=$(sed -n "${LAST_START}p" "$TARGET" | sed "s/.*<< '//;s/'.*//")

if [ -z "$TERMINATOR" ]; then
  echo "Could not determine terminator name. Aborting."
  exit 1
fi

echo "Missing terminator: $TERMINATOR"

# Append missing terminator to end of file
echo "$TERMINATOR" >> "$TARGET"

echo "Inserted missing terminator '$TERMINATOR' at end of file."
echo "bootstrap.sh repaired successfully."
