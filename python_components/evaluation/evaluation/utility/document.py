from pathlib import Path
import os
import urllib

from deepeval.test_case import MLLMImage
import pandas as pd
import pdf2image


def convert_to_images(row: pd.Series, output_path: str) -> list:
    path_obj = Path(row["url"])
    file_name_stem = path_obj.stem
    if '.cfm' in path_obj.suffix:
        file_name_stem += path_obj.suffix
    output_folder = f"{output_path}/{file_name_stem}"
    os.makedirs(output_folder, exist_ok=True)
    get_file(row["url"], output_folder)
    image_output = f"{output_folder}/images"
    os.makedirs(image_output, exist_ok=True)
    return pdf_to_attachments(f"{output_folder}/{path_obj.name}", image_output, 7)


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