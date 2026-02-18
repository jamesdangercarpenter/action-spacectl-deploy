#!/bin/bash

# Check for required input file
if [ -z "$1" ]; then
  echo "Usage: $0 input_file.json output_file.slack [run_url] [stack_name]"
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
RUN_URL="$3"
STACK_NAME="$4"

# Ensure jq is installed
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is not installed. Install it and try again."
  exit 1
fi

# Summary counts
ADD=$(jq '[.[].Resources[] | select(.Metadata.Type | startswith("ADD"))]      | length' "$INPUT_FILE")
CHANGE=$(jq '[.[].Resources[] | select(.Metadata.Type | startswith("CHANGE"))]  | length' "$INPUT_FILE")
REPLACE=$(jq '[.[].Resources[] | select(.Metadata.Type | startswith("REPLACE"))] | length' "$INPUT_FILE")
MOVE=$(jq '[.[].Resources[] | select(.Metadata.Type | startswith("NOOP"))]    | length' "$INPUT_FILE")
DELETE=$(jq '[.[].Resources[] | select(.Metadata.Type | startswith("DELETE"))]  | length' "$INPUT_FILE")
TOTAL=$((ADD + CHANGE + REPLACE + MOVE + DELETE))

# Write empty file when there are no changes; the assembler uses this to build the "no changes" list
if [ "$TOTAL" -eq 0 ]; then
  : >"$OUTPUT_FILE"
  echo "No changes, empty slack file written to $OUTPUT_FILE"
  exit 0
fi

TEXT=$(printf '*%s*\nAdd: %s | Change: %s | Replace: %s | Move: %s | Delete: %s' \
  "$STACK_NAME" "$ADD" "$CHANGE" "$REPLACE" "$MOVE" "$DELETE")

for TYPE_INFO in "ADD:To add" "CHANGE:To change" "REPLACE:To replace" "NOOP:To move" "DELETE:To destroy"; do
  TYPE="${TYPE_INFO%%:*}"
  LABEL="${TYPE_INFO#*:}"
  COUNT=$(jq "[.[].Resources[] | select(.Metadata.Type | startswith(\"$TYPE\"))] | length" "$INPUT_FILE")
  if [ "$COUNT" -gt 0 ]; then
    RESOURCES=$(jq -r --arg t "$TYPE" '.[].Resources[] | select(.Metadata.Type | startswith($t)) | "• `\(.Address)`"' "$INPUT_FILE")
    TEXT=$(printf '%s\n\n*%s:*\n%s' "$TEXT" "$LABEL" "$RESOURCES")
  fi
done

if [ -n "$RUN_URL" ]; then
  TEXT=$(printf '%s\n\n<%s|View full plan in Spacelift>' "$TEXT" "$RUN_URL")
fi

printf '%s' "$TEXT" >"$OUTPUT_FILE"
echo "✅ Slack plan saved to $OUTPUT_FILE"
