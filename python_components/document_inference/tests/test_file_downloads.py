import os

from document_inference.helpers import get_file
from pytest import raises
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


def test_first_strategy_fails_second_succeeds(httpserver: HTTPServer):
    call_count = {"count": 0}

    def handler(request: Request):
        call_count["count"] += 1
        # First call (minimal headers) fails, second call (browser headers) succeeds
        if call_count["count"] == 1:
            return Response("Forbidden", 403)
        else:
            return Response("Success on second try!", 200)

    httpserver.expect_request("/test.pdf").respond_with_handler(handler)
    _remove_file_if_exists("/tmp/test.pdf")
    get_file(httpserver.url_for("/test.pdf"), "/tmp", wait_to_retry=0)
    _assert_file_contents("/tmp/test.pdf", "Success on second try!")
    assert call_count["count"] == 2, "Should have tried exactly 2 strategies"


def test_multiple_strategies_fail_then_succeed(httpserver: HTTPServer):
    call_count = {"count": 0}

    def handler(request: Request):
        call_count["count"] += 1
        # First 3 calls fail, 4th succeeds
        if call_count["count"] < 4:
            return Response("Forbidden", 403)
        else:
            return Response("Success on fourth try!", 200)

    httpserver.expect_request("/test.pdf").respond_with_handler(handler)
    _remove_file_if_exists("/tmp/test.pdf")
    get_file(httpserver.url_for("/test.pdf"), "/tmp", wait_to_retry=0)
    _assert_file_contents("/tmp/test.pdf", "Success on fourth try!")
    assert call_count["count"] == 4, "Should have tried exactly 4 strategies"


def test_all_strategies_fail(httpserver: HTTPServer):
    """Test that when all strategies fail, we raise an exception."""

    def handler(request: Request):
        return Response("Forbidden", 403)

    httpserver.expect_request("/test.pdf").respond_with_handler(handler)
    _remove_file_if_exists("/tmp/test.pdf")

    with raises(RuntimeError, match="Failed to download file with all strategies"):
        get_file(httpserver.url_for("/test.pdf"), "/tmp", wait_to_retry=0)


def _remove_file_if_exists(path: str):
    if os.path.exists(path):
        os.remove(path)
    assert not os.path.exists(path)


def _assert_file_contents(path: str, contents: str):
    with open(path, "r") as f:
        assert f.read() == contents
