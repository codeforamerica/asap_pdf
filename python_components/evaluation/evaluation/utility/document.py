from pathlib import Path
import os
import urllib
from typing import Any, Optional, List

from deepeval.test_case import MLLMImage
import pdf2image
from pydantic import BaseModel

class Document(BaseModel):
    file_name: str
    url: str
    category: str
    human_summary: Optional[str] = None
    ai_summary: Optional[str] = None
    images: Optional[list] = None

class Result(BaseModel):
    score: float
    reason: str
    details: dict

def add_images_to_document(document: Document, output_path: str) -> None:
    path_obj = Path(document.url)
    file_name_stem = path_obj.stem
    if '.cfm' in path_obj.suffix:
        file_name_stem += path_obj.suffix
    output_folder = f"{output_path}/{file_name_stem}"
    os.makedirs(output_folder, exist_ok=True)
    get_file(document.url, output_folder)
    image_output = f"{output_folder}/images"
    os.makedirs(image_output, exist_ok=True)
    # todo parameterize page_limit
    document.images = pdf_to_attachments(f"{output_folder}/{path_obj.name}", image_output, 7)


def get_file(url: str, output_path: str) -> str:
    file_name = os.path.basename(url)
    local_path = f"{output_path}/{file_name}"
    urllib.request.urlretrieve(url, local_path)
    return local_path


def pdf_to_attachments(pdf_path: str, output_path: str, page_limit: int) -> list:
    images = pdf2image.convert_from_path(pdf_path, fmt="jpg", dpi=100)
    attachments = []
    for page, image in enumerate(images):
        if 0 < page_limit - 1 < page:
            break
        page_path = f"{output_path}/page-{page}.jpg"
        image.save(page_path)
        attachments.append(MLLMImage(page_path, local=True))
    return attachments


def convert_model_list(list: List[Any]) -> list:
    return [dict(item) if isinstance(item, BaseModel) else item for item in list]