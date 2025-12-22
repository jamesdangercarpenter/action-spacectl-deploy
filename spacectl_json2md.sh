#!/bin/bash

# Check for required input file
if [ -z "$1" ]; then
  echo "Usage: $0 input_file.json output_file.md"
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
RUN_URL="$3"

# Ensure jq is installed
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is not installed. Install it and try again."
  exit 1
fi

# Summary counts
for TYPE in ADD CHANGE REPLACE DELETE NOOP; do
  COUNT=$(jq "[.[].Resources[] | select(.Metadata.Type | startswith(\"$TYPE\")) ] | length" "$INPUT_FILE")
  if [ "$TYPE" = "NOOP" ]; then
    TYPE="MOVE"
  fi
  ROW1+="|$TYPE"
  ROW2+="|--"
  ROW3+="|$COUNT"
done

echo "$ROW1 |" >>"$OUTPUT_FILE"
echo "$ROW2 |" >>"$OUTPUT_FILE"
echo "$ROW3 |" >>"$OUTPUT_FILE"

echo "<details><summary>Details</summary>" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"

# Detail sections
print_section() {
  TYPE="$1"
  HEADING="$2"

  MATCHING=$(jq "[.[].Resources[] | select(.Metadata.Type | startswith(\"$TYPE\")) ] | length" "$INPUT_FILE")
  if [ "$MATCHING" -gt 0 ]; then
    echo "#### $HEADING" >>"$OUTPUT_FILE"
    jq -r --arg TYPE "$TYPE" '
      .[].Resources[]
      | select(.Metadata.Type | startswith($TYPE))
      | "- `" + .Address + "`"
    ' "$INPUT_FILE" >>"$OUTPUT_FILE"
    echo "" >>"$OUTPUT_FILE"
  fi
}

print_section "ADD" "🟢 Resources to Add"
print_section "CHANGE" "🟡 Resources to Change"
print_section "REPLACE" "🔁 Resources to Replace"
print_section "NOOP" "➡️ Resources to Move"
print_section "DELETE" "🔴 Resources to Destroy"

if [ -n "$RUN_URL" ]; then
  echo -n "**Full run summary:** " >>"$OUTPUT_FILE"
  echo "<$RUN_URL>" >>"$OUTPUT_FILE"
  echo "" >>"$OUTPUT_FILE"
fi

echo "</details>" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"
echo "✅ Markdown plan saved to $OUTPUT_FILE"
