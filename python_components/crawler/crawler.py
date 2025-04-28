import argparse
import csv
import io
import json
import re
import time
import urllib.parse
import urllib.robotparser
from collections import defaultdict, deque
from datetime import datetime

import pymupdf
import requests
import tldextract
from bs4 import BeautifulSoup
from tqdm import tqdm


def get_config(url):
    with open("config.json", "r") as f:
        config = json.load(f)

    try:
        return config[url]
    except KeyError:
        raise Exception("URL provided not in config.json")


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


def get_all_pages(all_pages, delay=0):
    pdfs = defaultdict(list)
    for page in tqdm(all_pages, ncols=100):
        time.sleep(delay)
        links, link_texts = get_links(page)
        for link, text in zip(links, link_texts):
            if link.endswith(".pdf") or re.search(r"\.cfm\?id=", link):
                # Save the source and PDF location
                pdfs[link].append({"source": page, "text": text})
    return pdfs


def bfs_search_pdfs(
    url, allowable_domains, allowable_subdomains=None, delay=0, max_depth=7, timeout=90
):
    # Restricts search to links sharing the same domain, capture all PDFs
    # along the way
    visited = set()  # Set to keep track of visited nodes
    queue = deque([(url, max_depth)])  # Queue to store nodes to visit
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
                allowable = any(
                    [(new_domain == domain) for domain in allowable_domains]
                )
                if allowable_subdomains:
                    new_subdomain = tldextract.extract(link).subdomain
                    matching_subdomains = any(
                        [
                            (new_subdomain == subdomain)
                            for subdomain in allowable_subdomains
                        ]
                    )
                    allowable = allowable and matching_subdomains

                new_depth = depth - 1
                if link.endswith(".pdf") or re.search(r"\.cfm\?id=", link) or link.endswith("/download"):  # noqa: E501
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


def get_images_and_tables(pages, min_width=100, min_height=100):
    number_of_images, number_of_tables = 0, 0
    for page in pages:
        number_of_tables += len(page.find_tables().tables)
        for image_info in page.get_image_info():
            width, height = image_info["width"], image_info["height"]
            if (width > min_width) and (height > min_height):
                number_of_images += 1
    return (number_of_images, number_of_tables)


def parse_pdf_date(date_string):
    # Removes the timeszone information from the date string
    if len(date_string) == 0:
        return None
    return datetime.strptime(date_string[2:14], "%Y%m%d%H%M%S")


def get_pdf_metadata(pdfs, output_path):
    with open(output_path, "w", newline="") as csv_file:
        csv_writer = csv.DictWriter(
            csv_file,
            fieldnames=[
                "file_name",
                "url",
                "file_size",
                "file_size_kilobytes",
                "last_modified_date",
                "author",
                "subject",
                "keywords",
                "creation_date",
                "producer",
                "number_of_pages",
                "number_of_tables",
                "number_of_images",
                "version",
                "source",
                "text_around_link",
            ],
        )
        csv_writer.writeheader()
        for pdf_url in tqdm(pdfs.keys(), ncols=100):
            source = list(set([dat["source"] for dat in pdfs[pdf_url]]))
            texts = list(set([dat["text"] for dat in pdfs[pdf_url]]))

            url_parsed = urllib.parse.urlparse(pdf_url)
            default_file_name = url_parsed.path.split("/")[-1]
            if len(default_file_name) == 0:
                default_file_name = url_parsed.netloc.split("\\")[-1]

            try:
                headers = {
                    "Content-Type": "application/pdf",
                    "Content-Disposition": "inline",
                }
                response = requests.get(
                    url=pdf_url, timeout=90, headers=headers, allow_redirects=True
                )
                if response.status_code < 400:
                    with io.BytesIO(response.content) as mem_obj:
                        try:
                            pdf_file = pymupdf.Document(stream=mem_obj)

                            file_name = default_file_name
                            pdf_title = pdf_file.metadata.get("title")
                            if pdf_title and (len(pdf_title.strip()) > 0):
                                file_name = pdf_title
                            file_bytes = mem_obj.getbuffer().nbytes
                            n_images, n_tables = get_images_and_tables(pdf_file.pages())
                            modified = parse_pdf_date(pdf_file.metadata.get("modDate"))
                            created = parse_pdf_date(
                                pdf_file.metadata.get("creationDate")
                            )

                            row = {
                                "file_name": file_name,
                                "url": pdf_url,
                                "file_size": convert_bytes(file_bytes),
                                "file_size_kilobytes": file_bytes / 1024,
                                "last_modified_date": modified,
                                "author": pdf_file.metadata.get("author"),
                                "subject": pdf_file.metadata.get("subject"),
                                "keywords": pdf_file.metadata.get("keywords"),
                                "creation_date": created,
                                "producer": pdf_file.metadata.get("producer"),
                                "number_of_pages": pdf_file.page_count,
                                "number_of_tables": n_tables,
                                "number_of_images": n_images,
                                # TODO: This is consistent with current behavior, but
                                # pdf_file.version_count might be more appropriate
                                "version": pdf_file.metadata.get("format"),
                                "source": source,
                                "text_around_link": texts,
                            }
                            csv_writer.writerow(row)
                        except:  # noqa:
                            # print(f'Error reading: {pdf_url}')
                            continue
            except:  # noqa
                # print(f'Error reading: {pdf_url}')
                continue

    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Starts crawl from provided URL")
    parser.add_argument("url", help="Starting URL")
    parser.add_argument("--delay", type=float, default=0, help="Delay between requests")
    parser.add_argument(
        "output_path", help="Path where a CSV with PDF information will be saved"
    )
    args = parser.parse_args()

    config = get_config(args.url)
    allow_list = config["allow_list"]
    allowable_subdomains = config.get("allow_subdomains")
    use_sitemap = config["use_sitemap"]
    depth = config["depth"]

    allowable_domains = [
        tldextract.extract(link).registered_domain for link in allow_list
    ]
    sitemap, manual_crawl_delay = parse_robots_txt(args.url, args.delay)

    if use_sitemap:
        all_pages = parse_sitemap(sitemap)
        print(f"Pages found from sitemap: {len(all_pages)}")

        pdfs = get_all_pages(all_pages, delay=manual_crawl_delay)
        print("Visited all pages on the sitemap.")
    else:
        print("Doing recursive search instead.")
        pdfs, visited = bfs_search_pdfs(
            args.url,
            allowable_domains,
            allowable_subdomains=allowable_subdomains,
            delay=manual_crawl_delay,
            max_depth=depth,
        )

    print(f"PDFs found: {len(pdfs)}")
    with open(args.output_path.replace(".csv", ".json"), "w") as f:
        json.dump(dict(pdfs), f, indent=4)
    get_pdf_metadata(pdfs, args.output_path)
