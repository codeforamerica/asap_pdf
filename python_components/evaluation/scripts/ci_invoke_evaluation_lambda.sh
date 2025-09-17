#!/bin/bash

BRANCH_NAME=$(git branch --show-current)

TMP_PAYLOAD=$(mktemp)

jq -n \
       --arg eval_model "$EVALUATION_MODEL" \
       --arg inference_model "$INFERENCE_MODEL" \
       --arg evaluation_component "$EVALUATION_COMPONENT" \
       --arg branch "$BRANCH_NAME" \
       --arg commit "$COMMIT_SHA" \
       --arg delta "$DELTA" \
       --argjson doc "$DOC"  \
       '{
         evaluation_model: $eval_model,
         inference_model: $inference_model,
         evaluation_component: $evaluation_component,
         branch_name: $branch,
         commit_sha: $commit,
         page_limit: 7,
         output_google_sheet: true,
         delta: $delta,
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
  "output.json" > "aws_response.json"

echo "AWS Response Metadata:"
cat aws_response.json

echo "Lambda Function Output:"
cat output.json

if grep -q '"FunctionError"' aws_response.json; then
    echo "Error: Lambda function failed with unhandled exception"
    exit 1
fi

if grep -q '"statusCode": 500' output.json; then
    echo "Error: Found StatusCode 500 in Lambda response"
    exit 1
fi