#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCH_NAME=$(git branch --show-current)

counter=0
while IFS= read -r line; do
    TMP_PAYLOAD="/tmp/lambda-payload-$$-$counter.json"

    jq -n \
       --arg eval_model "$EVALUATION_MODEL" \
       --arg inference_model "$INFERENCE_MODEL" \
       --arg evaluation_component "$EVALUATION_COMPONENT" \
       --arg bucket "$OUTPUT_BUCKET_NAME" \
       --arg branch "$BRANCH_NAME" \
       --arg commit "$COMMIT_SHA" \
       --argjson docs "$line"  \
       '{
         evaluation_model: $eval_model,
         inference_model: $inference_model,
         evaluation_component: $evaluation_component,
         branch_name: $branch,
         commit_sha: $commit,
         page_limit: 7,
         output_google_sheet: true,
         documents: [$docs]
       }' > "$TMP_PAYLOAD"

    echo "Invoking Lambda with payload:"
    cat $TMP_PAYLOAD

    aws lambda invoke \
      --cli-read-timeout 900 \
      --function-name $FUNCTION_NAME \
      --cli-binary-format raw-in-base64-out \
      --payload "file://$TMP_PAYLOAD" \
      --invocation-type Event \
      "output-$counter.json" &

    ((counter++))
done < <(jq -c '.[]' $SCRIPT_DIR/../truthset.json)

wait
cat output-*.json
