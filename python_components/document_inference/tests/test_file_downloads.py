import os

from document_inference.helpers import get_file
from pytest_httpserver import HTTPServer
from werkzeug import Request, Response

"""
Tests to assert that our file getting method works with some known curveballs.
"""


def test_default_behavior(httpserver: HTTPServer):
    def handler(request: Request):
        return Response("Plain pdf content!", 200)

    httpserver.expect_request("/test.pdf").respond_with_handler(handler)
    _remove_file_if_exists("/tmp/test.pdf")
    get_file(httpserver.url_for("/test.pdf"), "/tmp")
    _assert_file_contents("/tmp/test.pdf", "Plain pdf content!")


def test_content_disposition(httpserver: HTTPServer):
    def handler(request: Request):
        return Response(
            "Great pdf content!",
            200,
            headers={"Content-Disposition": "attachment", "filename": "mypdf.pdf"},
        )

    httpserver.expect_request("/test.pdf").respond_with_handler(handler)
    _remove_file_if_exists("/tmp/test.pdf")
    get_file(httpserver.url_for("/test.pdf"), "/tmp")
    _assert_file_contents("/tmp/test.pdf", "Great pdf content!")


def test_header_assertion(httpserver: HTTPServer):
    def handler(request: Request):
        try:
            headers_as_text = str(request.headers)
            assert (
                "python" not in headers_as_text
            ), f"Headers contain 'python': {headers_as_text}"
            assert (
                "urllib" not in headers_as_text
            ), f"Headers contain 'urllib': {headers_as_text}"
            assert (
                "Mozilla" in headers_as_text
            ), f"Headers missing 'Mozilla': {headers_as_text}"
            return Response("Great pdf validated by headers content!", 200)
        except AssertionError as e:
            print(f"Assertion failed: {e}")
            return Response(f"Assertion failed: {e}", 500)

    httpserver.expect_request("/test.pdf").respond_with_handler(handler)
    _remove_file_if_exists("/tmp/test.pdf")
    get_file(httpserver.url_for("/test.pdf"), "/tmp")
    _assert_file_contents("/tmp/test.pdf", "Great pdf validated by headers content!")


def test_308_redirect(httpserver: HTTPServer):
    def redirect_handler(request: Request):
        return Response(
            "",
            status=308,
            headers={
                "Location": httpserver.url_for("/redirected.pdf"),
                "Cache-Control": "max-age=3600",
            },
        )

    def final_handler(request: Request):
        return Response("Great redirected content!", 200)

    httpserver.expect_request("/original.pdf").respond_with_handler(redirect_handler)
    httpserver.expect_request("/redirected.pdf").respond_with_handler(final_handler)
    _remove_file_if_exists("/tmp/original.pdf")
    get_file(httpserver.url_for("/original.pdf"), "/tmp")
    _assert_file_contents("/tmp/original.pdf", "Great redirected content!")


def _remove_file_if_exists(path: str):
    if os.path.exists(path):
        os.remove(path)
    assert not os.path.exists(path)


def _assert_file_contents(path: str, contents: str):
    with open(path, "r") as f:
        assert f.read() == contents
