import datetime

from crawler import convert_bytes, parse_pdf_date, remove_trailing_slash


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
