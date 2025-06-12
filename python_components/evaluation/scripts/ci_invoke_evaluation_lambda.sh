#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCH_NAME=$(git branch --show-current)

PAYLOAD=$(jq -n \
       --arg eval_model "$EVALUATION_MODEL" \
       --arg inference_model "$INFERENCE_MODEL" \
       --arg evaluation_component "$EVALUATION_COMPONENT" \
       --arg branch "$BRANCH_NAME" \
       --arg commit "$COMMIT_SHA" \
       --argjson docs "$DOC"  \
       '{
         evaluation_model: $eval_model,
         inference_model: $inference_model,
         evaluation_component: $evaluation_component,
         branch_name: $branch,
         commit_sha: $commit,
         page_limit: 7,
         output_google_sheet: true,
         documents: [$DOC]
       }')

echo $PAYLOAD

aws lambda invoke \
  --cli-read-timeout 900 \
  --function-name $FUNCTION_NAME \
  --cli-binary-format raw-in-base64-out \
  --payload $PAYLOAD \
  "output.json"
