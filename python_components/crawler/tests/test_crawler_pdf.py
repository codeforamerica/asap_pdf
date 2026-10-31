import datetime
from types import SimpleNamespace

import crawler
import pymupdf
import pytest
from crawler import add_pdf_metadata

"""
Tests for the crawler's use of PyMuPDF, so that library upgrades which change how
documents are opened or analyzed are caught in CI.
"""

PDF_URL = "https://example.gov/files/report.pdf"


def _png(size):
    pixmap = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, size, size), 0)
    return pixmap.tobytes("png")


def _sample_pdf():
    doc = pymupdf.open()
    page = doc.new_page()
    # A bordered 4x3 grid, which find_tables should detect as a single table.
    for row in range(4):
        for col in range(3):
            rect = pymupdf.Rect(
                72 + col * 120, 100 + row * 25, 192 + col * 120, 125 + row * 25
            )
            page.draw_rect(rect, color=(0, 0, 0), width=1)
            page.insert_text((rect.x0 + 5, rect.y0 + 17), f"R{row}C{col}", fontsize=10)
    # One image above the minimum size and one below it.
    page.insert_image(pymupdf.Rect(72, 300, 272, 500), stream=_png(200))
    page.insert_image(pymupdf.Rect(300, 300, 340, 340), stream=_png(50))
    doc.new_page()
    doc.set_metadata(
        {
            "title": "Annual Report",
            "author": "Records Office",
            "creationDate": "D:20240102030405-05'00'",
            "modDate": "D:20240607080910Z",
        }
    )
    return doc.tobytes()


def _crawl(monkeypatch, content):
    monkeypatch.setattr(
        crawler, "fetch_with_retry", lambda url: SimpleNamespace(content=content)
    )
    return add_pdf_metadata(
        {PDF_URL: [{"source": "https://example.gov", "text": "Annual report"}]}
    )


def test_add_pdf_metadata_reads_pdf(monkeypatch):
    content = _sample_pdf()
    opened = []
    document_class = pymupdf.Document

    def tracking_document(*args, **kwargs):
        opened.append(document_class(*args, **kwargs))
        return opened[-1]

    monkeypatch.setattr(crawler.pymupdf, "Document", tracking_document)
    df = _crawl(monkeypatch, content)
    assert opened[0].is_closed
    assert len(df) == 1
    row = df.iloc[0]
    assert row["file_name"] == "Annual Report"
    assert row["url"] == PDF_URL
    assert row["author"] == "Records Office"
    assert row["number_of_pages"] == 2
    assert row["number_of_tables"] == 1
    assert row["number_of_images"] == 1
    assert row["version"].startswith("PDF ")
    assert row["creation_date"] == datetime.datetime(2024, 1, 2, 3, 4, 5)
    assert row["last_modified_date"] == datetime.datetime(2024, 6, 7, 8, 9, 10)
    assert row["source"] == ["https://example.gov"]
    assert row["text_around_link"] == ["Annual report"]


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
    df = _crawl(monkeypatch, content)
    assert df.empty
