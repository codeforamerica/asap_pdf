import argparse
import re
import urllib.parse

import numpy as np
import pandas as pd
import requests
import xgboost as xgb
from bs4 import BeautifulSoup
from tqdm import tqdm

label_mapping = {
    0: "Letter",
    1: "Agenda",
    2: "Memo",
    3: "Notice",
    4: "Flyer",
    5: "Other",
    6: "Report",
    7: "Procurement",
    8: "Press",
    9: "Slides",
    10: "Job Announcement",
}


def get_words_from_url_list(x):
    words = []
    for each_url in x:
        url_path = urllib.parse.urlparse(each_url).path
        for chars in re.split("[^a-zA-Z]", url_path):
            if len(chars) > 0:
                words.append(chars.lower())
    return words


def get_words_around_links(pdfs):
    text_around_link = []
    for i, row in tqdm(pdfs.iterrows(), total=len(pdfs), ncols=100):
        # time.sleep(0.5) # Half a second delay?
        text_around_links = []
        for source in row["source_list"]:
            try:
                response = requests.get(source, timeout=120)  # Get page
                if response.status_code >= 400:
                    continue

                html_content = response.content  # Parse the source page
                soup = BeautifulSoup(html_content, "html.parser")
                tags = soup.find_all(lambda x: x.get("href") == row["url"])

                words_around_link = set([])  # Get text around the link
                for tag in tags:
                    words_around_link.update(
                        [
                            each.lower()
                            for each in re.split("[^a-zA-Z]", tag.get_text())
                            if len(each) > 0
                        ]
                    )
                text_around_links.extend(list(words_around_link))
            except Exception:
                continue
        text_around_link.append(text_around_links)
    return text_around_link


def get_features(pdfs_path):
    pdfs = pd.read_csv(pdfs_path)
    pdfs["number_of_pages"] = pdfs["number_of_pages"].astype(int)
    pdfs["source_list"] = pdfs["source"].apply(eval)
    pdfs["file_name"] = pdfs["file_name"].fillna("")

    # Get keywords around the file name, source, url
    pdfs["file_name_keywords"] = pdfs["file_name"].apply(
        lambda x: [
            chars.lower()
            for chars in re.split("[^a-zA-Z]", x)
            if ((len(chars) > 0) and (chars != "pdf"))
        ]
    )
    pdfs["source_keywords"] = pdfs["source_list"].apply(get_words_from_url_list)
    pdfs["url_keywords"] = pdfs["url"].apply(
        lambda x: [
            chars.lower()
            for chars in re.split("[^a-zA-Z]", urllib.parse.urlparse(x).path)
            if ((len(chars) > 0) and (chars != "pdf"))
        ]
    )

    # Convert the human readable file sizes into numerics.
    # TODO: Just export the PDF data with sizes in kilobytes / bytes
    pdfs["file_size_numeric"] = pdfs["file_size"].apply(
        lambda x: float(x[:-2]) * 1024 if (x[-2:] == "MB") else float(x[:-2])
    )

    # Check for a year in the file name. Could be predictive of an agenda / event
    pdfs["file_name_contains_year"] = pdfs["file_name"].apply(
        lambda x: 1 if re.search(r"(19|20)\d{2}", x) else 0
    )

    # Get keywords around the links to these PDFs
    pdfs["url_text_keywords"] = get_words_around_links(pdfs)
    return pdfs


def get_feature_matrix(pdfs):
    file_name_dummies = (
        pd.get_dummies(pdfs["file_name_keywords"].explode()).groupby(level=0).sum()
    )
    file_name_dummies.columns = "file_" + file_name_dummies.columns

    source_dummies = (
        pd.get_dummies(pdfs["source_keywords"].explode()).groupby(level=0).sum()
    )
    source_dummies.columns = "source_" + source_dummies.columns

    url_dummies = pd.get_dummies(pdfs["url_keywords"].explode()).groupby(level=0).sum()
    url_dummies.columns = "url_" + url_dummies.columns

    url_text_dummies = (
        pd.get_dummies(pdfs["url_text_keywords"].explode()).groupby(level=0).sum()
    )
    url_text_dummies.columns = "url_text_" + url_text_dummies.columns

    X = pd.concat(
        [
            file_name_dummies,
            source_dummies,
            url_text_dummies,
            pdfs[["file_size_numeric", "number_of_pages", "file_name_contains_year"]],
        ],
        axis=1,
    )
    return X


def get_predictions(feature_matrix, model_path):
    model = xgb.XGBClassifier()
    model.load_model(model_path)

    # The trained model must have the same columns as the data we're predicting on
    model_features = set(model.get_booster().feature_names)
    candidate_features = set(feature_matrix.columns)
    missing_features = list(model_features - candidate_features)
    if len(missing_features) > 0:
        missing_feature_matrix = pd.DataFrame(
            np.zeros((len(feature_matrix), len(missing_features))),
            columns=missing_features,
        )
        feature_matrix = pd.concat([feature_matrix, missing_feature_matrix], axis=1)

    feature_matrix = feature_matrix[list(model_features)]
    candidate_features = set(feature_matrix.columns)
    assert candidate_features == model_features

    feature_matrix = feature_matrix.sort_index(axis=1)
    prediction_probs = model.predict_proba(feature_matrix)
    predictions = model.predict(feature_matrix)
    confidences = [
        float(probs[category]) for category, probs in zip(predictions, prediction_probs)
    ]
    prediction_labels = [label_mapping[pred] for pred in predictions]
    return prediction_labels, confidences


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Uses paths to a CSV of PDFs and a model for document classification"
    )
    parser.add_argument("pdfs_path", help="Path to CSV with PDF information")
    parser.add_argument(
        "output_path", help="Path where a CSV with predictions will be saved"
    )
    args = parser.parse_args()

    pdf_features = get_features(args.pdfs_path)
    pdf_feature_matrix = get_feature_matrix(pdf_features)
    predictions, confidences = get_predictions(pdf_feature_matrix, "xgboost_model.json")

    output = pd.read_csv(args.pdfs_path)
    output["predicted_category"] = predictions
    output["predicted_category_confidence"] = confidences
    output.to_csv(args.output_path, index=False)
