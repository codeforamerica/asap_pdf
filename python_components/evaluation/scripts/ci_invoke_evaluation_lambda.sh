#!/bin/bash

BRANCH_NAME=$(git branch --show-current)

TMP_PAYLOAD=$(mktemp)

jq -n \
       --arg eval_model "$EVALUATION_MODEL" \
       --arg inference_model "$INFERENCE_MODEL" \
       --arg evaluation_component "$EVALUATION_COMPONENT" \
       --arg branch "$BRANCH_NAME" \
       --arg commit "$COMMIT_SHA" \
       --argjson doc "$DOC"  \
       '{
         evaluation_model: $eval_model,
         inference_model: $inference_model,
         evaluation_component: $evaluation_component,
         branch_name: $branch,
         commit_sha: $commit,
         page_limit: 7,
         output_google_sheet: true,
         documents: [$doc]
       }' > "$TMP_PAYLOAD"

cat "$TMP_PAYLOAD"

echo "AWS Max Attempts: $AWS_MAX_ATTEMPTS"

aws lambda invoke \
  --invocation-type RequestResponse \
  --cli-read-timeout 960 \
  --function-name $FUNCTION_NAME \
  --cli-binary-format raw-in-base64-out \
  --payload file://"$TMP_PAYLOAD" \
  "output.json"

cat output.json

if grep -q '"StatusCode": 500' output-*.json; then
    echo "Error: Found StatusCode 500 in Lambda responses"
    exit 1
fi