import datetime
import os
import urllib
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any, List

import boto3
import fitz
import pandas as pd
from deepeval.models import DeepEvalBaseMLLM
from deepeval.test_case import MLLMImage
from evaluation.utility.helpers import logger
from evaluation.utility.schema import Document, Result
from pydantic import BaseModel


class ResultFactory:

    def __init__(self, base_values: dict):
        self.base_values = base_values

    def new(self, values: dict) -> Result:
        return Result.model_validate({**self.base_values, **values})


class EvaluationWrapperBase(ABC):

    def __init__(
        self,
        evaluation_model: DeepEvalBaseMLLM | None,
        inference_model_name: str | None,
        branch_name: str,
        commit_sha: str,
        **kwargs,
    ):
        self.evaluation_model = evaluation_model
        self.inference_model_name = inference_model_name
        self.branch_name = branch_name
        self.commit_sha = commit_sha
        self.page_limit = kwargs.get("page_limit", 7)
        self.local_mode = kwargs.get("local_mode", False)
        self.result_factory = ResultFactory(
            {
                "evaluation_model": self.evaluation_model.model_name,
                "inference_model": self.inference_model_name,
                "branch_name": self.branch_name,
                "commit_sha": self.commit_sha,
                "metric_run_date": datetime.datetime.now().strftime(
                    "%Y-%m-%d %H-%M-%S"
                ),
            }
        )

    @abstractmethod
    def evaluate(self, document: Document) -> List[Result]:
        pass


def add_images_to_document(
    document: Document, output_path: str, page_limit: int
) -> None:
    path_obj = Path(document.url)
    file_name_stem = path_obj.stem
    if ".cfm" in path_obj.suffix:
        file_name_stem += path_obj.suffix
    output_folder = f"{output_path}/{file_name_stem}"
    os.makedirs(output_folder, exist_ok=True)
    get_file(document.url, output_folder)
    image_output = f"{output_folder}/images"
    os.makedirs(image_output, exist_ok=True)
    document.images = pdf_to_attachments(
        f"{output_folder}/{path_obj.name}", image_output, page_limit
    )


def get_file(url: str, output_path: str) -> str:
    file_name = os.path.basename(url)
    local_path = f"{output_path}/{file_name}"
    urllib.request.urlretrieve(url, local_path)
    return local_path


def pdf_to_attachments(
    pdf_path: str, output_path: str, page_limit: int, dpi=100
) -> list:
    doc = fitz.open(pdf_path)
    attachments = []
    file_name = os.path.splitext(os.path.basename(pdf_path))[0]
    logger.info(f"Found {doc.page_count} pages total.")
    logger.info(f"Page limit set to {page_limit} with dpi {dpi}.")
    for page_num in range(doc.page_count):
        if page_num >= page_limit:
            break
        page = doc.load_page(page_num)
        page_path = f"{output_path}/{file_name}-{page_num}.jpg"
        pix = page.get_pixmap(matrix=fitz.Matrix(dpi / 72, dpi / 72))
        pix.save(page_path)
        attachments.append(MLLMImage(page_path, local=True))
    return attachments


def convert_model_list(list: List[Any]) -> list:
    return [dict(item) if isinstance(item, BaseModel) else item for item in list]


def write_output_to_s3(
    bucket_name: str, report_name: str, report_content: List[dict]
) -> None:
    df = pd.DataFrame(report_content)
    tmp_path = f"/tmp/data/{report_name}"
    df.to_csv(tmp_path, index=False)
    s3 = boto3.resource("s3")
    s3.Bucket(bucket_name).upload_file(tmp_path, f"/reports/{report_name}")
