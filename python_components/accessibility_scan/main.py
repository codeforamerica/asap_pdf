import json
import os

from axe_selenium_python import Axe
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

ACCESSIBILITY_SCAN_HOST = os.getenv("ACCESSIBILITY_SCAN_HOST", "localhost")

TAGS = ["wcag2a", "wcag2aa", "wcag21aa"]

ANON_URLS_TO_SCAN = (f"http://{ACCESSIBILITY_SCAN_HOST}:3000",)

AUTHED_URLS_TO_SCAN = (
    f"http://{ACCESSIBILITY_SCAN_HOST}:3000/sites",
    f"http://{ACCESSIBILITY_SCAN_HOST}:3000/sites/1/documents",
    f"http://{ACCESSIBILITY_SCAN_HOST}:3000/sites/1/insights",
    f"http://{ACCESSIBILITY_SCAN_HOST}:3000/sites/1/documents/302/modal_content",
)


def scan_urls():
    # Automatically manage geckodriver
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    service = Service("/usr/local/bin/geckodriver")
    driver = webdriver.Firefox(service=service, options=options)

    all_results = {
        "total_violations": 0,
        "total_incomplete": 0,
        "anon_urls": {},
        "authed_urls": {},
    }

    for url in ANON_URLS_TO_SCAN:
        driver.get(url)
        driver.implicitly_wait(5)
        results = get_axe_results(driver)
        all_results["total_violations"] += len(results["violations"])
        all_results["anon_urls"][url] = results

    if AUTHED_URLS_TO_SCAN is not None:
        # Log into the app.
        wait = WebDriverWait(driver, 10)
        email_field = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "#user_email"))
        )
        password_field = driver.find_element(By.CSS_SELECTOR, "#user_password")
        email_field.send_keys("admin@codeforamerica.org")
        password_field.send_keys("password")
        submit_button = driver.find_element(By.CSS_SELECTOR, "#submit-session-form")
        submit_button.click()
        wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "#add-site-modal")))

        for url in AUTHED_URLS_TO_SCAN:
            driver.get(url)
            driver.implicitly_wait(5)
            results = get_axe_results(driver)
            all_results["total_violations"] += len(results["violations"])
            all_results["total_incomplete"] += len(results["incomplete"])
            all_results["authed_urls"][url] = results

    driver.quit()

    print(json.dumps(all_results, indent=2))


def get_axe_results(driver):
    axe = Axe(driver)
    axe.inject()
    return axe.run({"runOnly": {"type": "tag", "values": TAGS}})


if __name__ == "__main__":
    scan_urls()
