from classifier import get_words_around_links, get_words_from_url_list


def test_get_words_from_url_list():
    url_list = [
        "https://example.com/path-to-report/",
        "https://example.com/Another-Route/",
    ]
    assert get_words_from_url_list(url_list) == [
        "path",
        "to",
        "report",
        "another",
        "route",
    ]

    url_list = [
        "https://example.com/path-to-report/",
        "https://example.com/Another-Route/a-little-further",
    ]
    assert get_words_from_url_list(url_list) == [
        "path",
        "to",
        "report",
        "another",
        "route",
        "a",
        "little",
        "further",
    ]


def test_get_words_around_links():
    text_around_link = ["Report", "download-here", "Pdf"]
    assert sorted(get_words_around_links(text_around_link)) == [
        "download",
        "here",
        "pdf",
        "report",
    ]
