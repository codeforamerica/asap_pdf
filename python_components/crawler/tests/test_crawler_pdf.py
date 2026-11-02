from types import SimpleNamespace

import crawler
import pymupdf
import pytest
from crawler import add_pdf_metadata

"""
Tests that the crawler skips downloads which aren't PDFs. PyMuPDF opens some
non-PDF formats, like HTML and images, as documents.
"""


def _png(size):
    pixmap = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, size, size), 0)
    return pixmap.tobytes("png")


@pytest.mark.parametrize(
    "content",
    [
        pytest.param(b"just some text", id="text"),
        pytest.param(b"\x00\x01\x02nonsense", id="garbage"),
        pytest.param(b"", id="empty"),
        pytest.param(b"<html><body><h1>404 Not Found</h1></body></html>", id="html"),
        pytest.param(_png(200), id="png"),
    ],
)
def test_add_pdf_metadata_skips_non_pdf(monkeypatch, content):
    monkeypatch.setattr(
        crawler, "fetch_with_retry", lambda url: SimpleNamespace(content=content)
    )
    df = add_pdf_metadata(
        {"https://example.gov/report.pdf": [{"source": "", "text": ""}]}
    )
    assert df.empty
