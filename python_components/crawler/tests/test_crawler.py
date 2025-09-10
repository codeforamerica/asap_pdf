import datetime
import sys
from pathlib import Path

import pandas as pd
from crawler import (
    compare_crawled_documents,
    convert_bytes,
    parse_pdf_date,
    remove_trailing_slash,
)


def test_convert_bytes():
    assert convert_bytes(100) == "100.0"
    assert convert_bytes(1024) == "1.0KB"
    assert convert_bytes(1024 * 1024) == "1.0MB"
    assert convert_bytes(1024 * 1024 * 1024) == "1.0GB"


def test_remove_trailing_slash():
    assert remove_trailing_slash("https://example.com/") == "https://example.com"
    assert remove_trailing_slash("https://example.com") == "https://example.com"


def test_parse_pdf_date():
    assert parse_pdf_date("20000102030405") == datetime.datetime(2000, 1, 2, 3, 4, 5)
    assert parse_pdf_date("D:20000102030405") == datetime.datetime(2000, 1, 2, 3, 4, 5)
    assert parse_pdf_date("D:20000102030405Z") == datetime.datetime(2000, 1, 2, 3, 4, 5)
    assert parse_pdf_date("D:20000102030405-06'00'") == datetime.datetime(
        2000, 1, 2, 3, 4, 5
    )


def test_comparison():
    sys.path.insert(0, str(Path(__file__).parent.parent))
    test_dir = Path(__file__).parent
    first_crawl = pd.read_csv(f"{test_dir}/fixtures/first_crawl.csv")
    second_crawl = pd.read_csv(f"{test_dir}/fixtures/second_crawl.csv")
    third_crawl = pd.read_csv(f"{test_dir}/fixtures/third_crawl.csv")
    comparison = compare_crawled_documents(second_crawl, first_crawl)
    assert len(comparison[comparison["crawl_status"] == "new"]) == 2
    assert len(comparison[comparison["crawl_status"] == "active"]) == 2
    assert len(comparison[comparison["crawl_status"] == "removed"]) == 0
    comparison = compare_crawled_documents(third_crawl, comparison)
    assert len(comparison[comparison["crawl_status"] == "new"]) == 2
    assert len(comparison[comparison["crawl_status"] == "active"]) == 2
    assert len(comparison[comparison["crawl_status"] == "removed"]) == 2
    assert list(first_crawl.columns) + ["crawl_status"] == list(comparison.columns)
