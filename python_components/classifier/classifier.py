import argparse
import json
import re
import urllib.parse
import warnings

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.preprocessing import MultiLabelBinarizer

warnings.filterwarnings("ignore")


def get_labels():
    with open("labels.json", "r") as f:
        return json.load(f)


def get_words_from_url_list(x):
    words = []
    for each_url in x:
        url_path = urllib.parse.urlparse(each_url).path
        for chars in re.split("[^a-zA-Z]", url_path):
            if len(chars) > 0:
                words.append(chars.lower())
    return words


def get_words_around_links(x):
    words_around_link = set([])
    for phrase in x:
        words_around_link.update(
            [each.lower() for each in re.split("[^a-zA-Z]", phrase) if len(each) > 0]
        )
    return list(words_around_link)


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
    pdfs["producer"] = pdfs["producer"].astype(str)
    pdfs["producer_keywords"] = pdfs["producer"].apply(
        lambda x: [
            chars.lower() for chars in re.split("[^a-zA-Z]", x) if ((len(chars) > 0))
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
    # Use file size as a feature
    pdfs["file_size_numeric"] = pdfs["file_size_kilobytes"].astype(float)

    # Check for a year in the file name. Could be predictive of an agenda / event
    pdfs["file_name_contains_year"] = pdfs["file_name"].apply(
        lambda x: 1 if re.search(r"(19|20)\d{2}", x) else 0
    )

    # Get keywords around the links to these PDFs
    pdfs["text_around_link"] = pdfs["text_around_link"].apply(eval)
    pdfs["url_text_keywords"] = pdfs["text_around_link"].apply(get_words_around_links)
    return pdfs


def get_feature_matrix(pdfs):
    mlb = MultiLabelBinarizer(sparse_output=True)
    file_name_dummies = pd.DataFrame.sparse.from_spmatrix(
        mlb.fit_transform(pdfs["file_name_keywords"])
    )
    file_name_dummies.columns = "file_" + mlb.classes_

    producer_dummies = pd.DataFrame.sparse.from_spmatrix(
        mlb.fit_transform(pdfs["producer_keywords"])
    )
    producer_dummies.columns = "producer_" + mlb.classes_

    source_dummies = pd.DataFrame.sparse.from_spmatrix(
        mlb.fit_transform(pdfs["source_keywords"])
    )
    if len(source_dummies.columns) > 0:
        source_dummies.columns = "source_" + mlb.classes_

    url_dummies = pd.DataFrame.sparse.from_spmatrix(
        mlb.fit_transform(pdfs["url_keywords"])
    )
    url_dummies.columns = "url_" + mlb.classes_

    url_text_dummies = pd.DataFrame.sparse.from_spmatrix(
        mlb.fit_transform(pdfs["url_text_keywords"])
    )
    url_text_dummies.columns = "url_text_" + mlb.classes_

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

    # Before we add any missing features, drop the ones the model hasn't seen
    unseen_labels = list(candidate_features - model_features)
    feature_matrix.drop(labels=unseen_labels, inplace=True, axis=1)
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

    labels = get_labels()
    label_mapping = {ind: label for label, ind in labels.items()}

    pdf_features = get_features(args.pdfs_path)
    pdf_feature_matrix = get_feature_matrix(pdf_features)
    del pdf_features
    predictions, confidences = get_predictions(pdf_feature_matrix, "xgboost_model.json")
    del pdf_feature_matrix

    output = pd.read_csv(args.pdfs_path)
    output["predicted_category"] = predictions
    output["predicted_category_confidence"] = confidences
    output.to_csv(args.output_path, index=False)
