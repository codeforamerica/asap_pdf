import argparse
import glob
from pathlib import Path

import pandas as pd


"""
Utility to randomly sample scraped csv files and output them into a small development set.
"""

def find_files(args: argparse.Namespace):
    for file in glob.glob(f"{args.input}/*.csv"):
        chunk_file(file, args.output_path, args.chunk_size)


def chunk_file(file: str, output_path, chunk_size: int):
    file_obj = Path(file)
    df = pd.read_csv(file, low_memory=False)
    df.sample(n=chunk_size).to_csv(f"{output_path}/{file_obj.name}", index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Splits scraped csv files into a smaller development set.")
    parser.add_argument("input", help="Folder of CSVs to split.")
    parser.add_argument("--chunk-size", type=int, default=100, help="Number of results to return.")
    parser.add_argument(
        "output_path", help="Path where a CSV with PDF information will be saved"
    )
    provided_args = parser.parse_args()
    find_files(provided_args)
