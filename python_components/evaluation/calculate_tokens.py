import json
import time

import pandas as pd

from evaluation.utility.schema import Document
from evaluation.utility.asap_inference import get_inference_for_document

LLM_RATES = {
    "gemini-2.0-flash": {
        "input_rate": 0.10 / 1000000,
        "output_rate": 0.40 / 1000000,
    },
    "gemini-2.5-pro-preview-03-25": {
        "input_rate": 1.25 / 1000000,
        "output_rate": 10.00 / 1000000,
    },
}


def get_truthset(path: str) -> list:
    truthset = []
    with open(path, "r") as f:
        json_data = json.loads(f.read())
    for file in json_data:
        truthset.append(Document(**file))
    return truthset


def make_inferences(truthset: list[Document]) -> None:
    inference_modes = (
        ("gemini-2.0-flash", "summary"),
        ("gemini-2.5-pro-preview-03-25", "exception")
    )
    output = []
    for document in truthset:
        for inference_mode in inference_modes:
            try:
                result = get_inference_for_document(document, *inference_mode, local_mode=True, aws_env="staging",
                                                    page_number=7)
                output.append({
                    "document": document.url,
                    "inference_mode": inference_mode[1],
                    "inference_llm": inference_mode[0],
                    "input_tokens": result["usage"]["input"],
                    "output_tokens": result["usage"]["output"],
                    "detail": json.dumps(result["usage"]),
                    **LLM_RATES[inference_mode[0]]
                })
                time.sleep(2)
            except Exception as e:
                print(f"Failed {inference_mode[1]} for document {document.url} skipping...")
    df = pd.DataFrame(output)
    df["input_cost"] = df["input_tokens"] * df["input_rate"]
    df["output_cost"] = df["output_tokens"] * df["output_rate"]
    df["total_cost"] = df["input_cost"] + df["output_cost"]
    df.to_csv("usage_report.csv", index=False)


if __name__ == "__main__":
    truthset = get_truthset("./truthset.json")
    make_inferences(truthset)
