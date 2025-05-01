#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the current branch
BRANCH_NAME=$(git branch --show-current)

# Get the documents JSON content
DOCUMENTS_JSON=$(cat $SCRIPT_DIR/../truthset.json)

TMP_PAYLOAD=$(mktemp)

jq -n \
   --arg model "$EVALUATION_MODEL" \
   --arg bucket "$OUTPUT_BUCKET_NAME" \
   --arg branch "$BRANCH_NAME" \
   --arg commit "$COMMIT_SHA" \
   --argjson docs "$DOCUMENTS_JSON"  \
   '{
     model_name: $model,
     output_s3_bucket: $bucket,
     branch_name: $branch,
     commit_sha: $commit,
     page_limit: 7,
     documents: $docs
   }' > $TMP_PAYLOAD

cat $TMP_PAYLOAD

aws lambda invoke \
  --cli-read-timeout 900 \
  --function-name $FUNCTION_NAME \
  --cli-binary-format raw-in-base64-out \
  --payload file://$TMP_PAYLOAD \
  response.json

cat response.json

if ! grep -q 'Successfully dumped report' response.json; then
  exit 1
fi