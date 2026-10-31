import fitz
import pymupdf
import pytest
from document_inference import helpers
from evaluation.utility import document

"""
Tests for rendering PDF pages to images with PyMuPDF in document_inference and
evaluation, so that library upgrades which change rendering are caught in CI.
"""


def test_fitz_is_pymupdf():
    assert fitz.open is pymupdf.open


@pytest.mark.parametrize("module", [helpers, document], ids=["inference", "evaluation"])
def test_pdf_to_attachments(module, tmp_path, monkeypatch):
    pdf_path = str(tmp_path / "sample.pdf")
    doc = fitz.open()
    for page_num in range(3):
        # US Letter, so page sizes in pixels are whole numbers at 100 dpi.
        doc.new_page(width=612, height=792).insert_text((72, 72), f"Page {page_num}")
    doc.save(pdf_path)
    doc.close()

    opened = []
    fitz_open = fitz.open

    def tracking_open(*args, **kwargs):
        opened.append(fitz_open(*args, **kwargs))
        return opened[-1]

    monkeypatch.setattr(module.fitz, "open", tracking_open)
    attachments = module.pdf_to_attachments(
        pdf_path, str(tmp_path), page_limit=2, dpi=100
    )

    assert len(attachments) == 2
    assert not (tmp_path / "sample-2.jpg").exists()
    image_path = tmp_path / "sample-0.jpg"
    assert image_path.read_bytes()[:3] == b"\xff\xd8\xff"
    pixmap = fitz.Pixmap(str(image_path))
    assert (pixmap.width, pixmap.height) == (850, 1100)
    assert opened[0].is_closed
