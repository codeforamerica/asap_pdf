import argparse
import io
import json
import re
import time
import urllib.parse
import urllib.robotparser
import warnings
from collections import defaultdict, deque

import pandas as pd
import pypdf
import requests
import tldextract
from bs4 import BeautifulSoup
from tqdm import tqdm

warnings.filterwarnings("ignore")


def get_config():
    with open("config.json", "r") as f:
        return json.load(f)


def parse_robots_txt(url, manual_crawl_delay):
    # Parse the site's robots.txt file
    rp = urllib.robotparser.RobotFileParser()
    rp.set_url(urllib.parse.urljoin(url, "robots.txt"))
    rp.read()

    # TODO: For the sites above, there is only one. Make more flexible
    sitemap = urllib.parse.urljoin(url, "sitemap.xml")  # Default
    if rp.site_maps():
        sitemap = rp.site_maps()[0]

    if rp.crawl_delay("*"):
        manual_crawl_delay += int(rp.crawl_delay("*"))
    return sitemap, manual_crawl_delay


def parse_sitemap(sitemap):
    r = requests.get(sitemap)
    soup = BeautifulSoup(r.text, "xml")
    more_site_maps = [site.text for site in soup.find_all("loc")]

    all_pages = set()
    for site in more_site_maps:
        if manual_crawl_delay:
            time.sleep(manual_crawl_delay)

        r = requests.get(site)
        soup = BeautifulSoup(r.text, "xml")
        all_pages.update([x.find("loc").text for x in soup.find_all("url")])

    return all_pages


def remove_trailing_slash(url_string):
    parsed_url = urllib.parse.urlparse(url_string)
    path = parsed_url.path

    if path.endswith("/"):
        path = path[:-1]

    updated_url = parsed_url._replace(path=path)
    return urllib.parse.urlunparse(updated_url)


def get_links(url, timeout=90):
    # Fetch the HTML content from a website
    try:
        response = requests.get(url, timeout=timeout)
        if response.status_code >= 400:
            return [], []

        # Parse HTML and retrieve all links
        html_content = response.content
        soup = BeautifulSoup(html_content, "html.parser")
        atags = soup.find_all("a")

        links, link_texts = [], []
        for atag in atags:
            if atag.get("href"):
                href = atag.get("href")
                link_texts.append(atag.get_text().strip())
                if href.startswith("http"):
                    links.append(remove_trailing_slash(href))
                else:
                    new_href = urllib.parse.urljoin(url, href)
                    links.append(remove_trailing_slash(new_href))
    except:  # noqa:
        # TODO: Be explicit on errors
        return [], []

    return links, link_texts


def get_all_pages(all_pages):
    pdfs = defaultdict(list)
    for page in tqdm(all_pages, ncols=100):
        if manual_crawl_delay:
            time.sleep(manual_crawl_delay)
        links, link_texts = get_links(page)
        for link, text in zip(links, link_texts):
            if link.endswith(".pdf") or re.search(r"\.cfm\?id=", link):
                # Save the source and PDF location
                pdfs[link].append({"source": page, "text": text})
    return pdfs


def bfs_search_pdfs(url, delay=0, max_depth=7, allowable_sites=[], timeout=90):
    # Restricts search to links sharing the same domain, capture all PDFs
    # along the way
    visited = set()  # Set to keep track of visited nodes
    queue = deque([(url, max_depth)])  # Queue to store nodes to visit
    if len(allowable_sites) == 0:
        allowable_sites = [url]
    pdfs = defaultdict(list)

    pbar = tqdm(unit=" pages")
    while queue:
        node, depth = queue.popleft()  # Get the next node from the queue
        pbar.update(1)
        if node not in visited:
            time.sleep(delay)
            visited.add(node)  # Mark the node as visited
            links, link_texts = get_links(node, timeout=timeout)

            # Add the node's neighbors to the queue, if they share the same
            # domain
            for link, text in zip(links, link_texts):
                new_domain = tldextract.extract(link).registered_domain
                allowable = any([(new_domain == domain) for domain in allowable_sites])
                new_depth = depth - 1
                if link.endswith(".pdf") or re.search(r"\.cfm\?id=", link):
                    # Save pdfs
                    pdfs[link].append({"source": node, "text": text})
                elif (link not in visited) and allowable and (new_depth > 0):
                    queue.append((link, new_depth))

    pbar.close()
    return pdfs, visited


# https://stackoverflow.com/questions/1094841/get-a-human-readable-version-of-a-file-size$0
def convert_bytes(file_size):
    for unit in ("", "KB", "MB", "GB", "TB", "PB", "EB", "ZB"):
        if abs(file_size) < 1024.0:
            return f"{file_size:3.1f}{unit}"
        file_size /= 1024.0
    return f"{file_size:.1f}YB"


def get_pdf_metadata(pdfs):
    rows = []
    for pdf_url in tqdm(pdfs.keys(), ncols=100):
        source = list(set([dat["source"] for dat in pdfs[pdf_url]]))
        texts = list(set([dat["text"] for dat in pdfs[pdf_url]]))

        url_parsed = urllib.parse.urlparse(pdf_url)
        default_file_name = url_parsed.path.split("/")[-1]
        if len(default_file_name) == 0:
            default_file_name = url_parsed.netloc.split("\\")[-1]

        try:
            response = requests.get(url=pdf_url, timeout=90)
            if response.status_code < 400:
                with io.BytesIO(response.content) as mem_obj:
                    try:
                        pdf_file = pypdf.PdfReader(mem_obj, strict=True)

                        file_name = default_file_name
                        pdf_title = pdf_file.metadata.title
                        if pdf_title and (len(pdf_title.strip()) > 0):
                            file_name = pdf_title
                        file_bytes = mem_obj.getbuffer().nbytes

                        row = {
                            "file_name": file_name,
                            "url": pdf_url,
                            "file_size": convert_bytes(file_bytes),
                            "file_size_kilobytes": file_bytes / 1024,
                            "last_modified_date": pdf_file.metadata.modification_date,  # noqa: E501
                            "author": pdf_file.metadata.author,
                            "subject": pdf_file.metadata.subject,
                            "keywords": pdf_file.metadata.keywords,
                            "creation_date": pdf_file.metadata.creation_date,
                            "producer": pdf_file.metadata.producer,
                            "number_of_pages": pdf_file.get_num_pages(),
                            "version": pdf_file.pdf_header,
                            "source": source,
                            "text_around_link": texts,
                        }
                        rows.append(row)
                    except:  # noqa:
                        # print(f'Error reading: {pdf_url}')
                        continue
        except:  # noqa
            # print(f'Error reading: {pdf_url}')
            continue

    return pd.DataFrame(rows)


config = get_config()
allow_list = config["allow_list"]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Starts crawl from provided URL")
    parser.add_argument("url", help="Starting URL", choices=allow_list.keys())
    parser.add_argument("--depth", type=int, default=5, help="Crawl depth")
    parser.add_argument("--delay", type=float, default=0, help="Delay between requests")
    parser.add_argument(
        "--use_sitemap",
        default=False,
        action=argparse.BooleanOptionalAction,
        help="Use sitemap (versus crawl recursively)",
    )
    parser.add_argument(
        "output_path", help="Path where a CSV with PDF information will be saved"
    )
    args = parser.parse_args()

    allowable_domains = [
        tldextract.extract(link).registered_domain for link in allow_list[args.url]
    ]
    sitemap, manual_crawl_delay = parse_robots_txt(args.url, args.delay)

    if args.use_sitemap:
        all_pages = parse_sitemap(sitemap)
        print(f"Pages found from sitemap: {len(all_pages)}")

        pdfs = get_all_pages(all_pages)
        print("Visited all pages on the sitemap.")
    else:
        print("Doing recursive search instead.")
        pdfs, visited = bfs_search_pdfs(
            args.url,
            delay=manual_crawl_delay,
            max_depth=args.depth,
            allowable_sites=allowable_domains,
        )

    print(f"PDFs found: {len(pdfs)}")
    pdf_metadata = get_pdf_metadata(pdfs)
    pdf_metadata.to_csv(args.output_path, index=False)
