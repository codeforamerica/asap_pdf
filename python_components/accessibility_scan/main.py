import json

from axe_selenium_python import Axe
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities

TAGS = ["wcag2a", "wcag2aa", "wcag21aa"]

ANON_URLS_TO_SCAN = ("http://localhost:3000",)

AUTHED_URLS_TO_SCAN = (
    "http://localhost:3000/sites",
    "http://localhost:3000/sites/1/documents"
    "http://localhost:3000/sites/1/insights",
)


def scan_urls():
    # Automatically manage geckodriver
    driver = create_firefox_driver()

    all_results = {
        "total_violations": 0,
        "anon_urls": {},
        "authed_urls": {},
    }

    for url in ANON_URLS_TO_SCAN:
        driver.get(url)
        driver.implicitly_wait(5)
        results = get_axe_results(driver)
        all_results["total_violations"] += len(results["violations"])
        all_results["anon_urls"][url] = results

    # Log into the app.
    wait = WebDriverWait(driver, 10)
    email_field = wait.until(
        EC.presence_of_element_located((By.CSS_SELECTOR, "#email_address"))
    )
    password_field = driver.find_element(By.CSS_SELECTOR, "#password")
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
        all_results["authed_urls"][url] = results

    driver.quit()

    print(json.dumps(all_results, indent=2))


def create_firefox_driver():
    """Create a Firefox WebDriver instance optimized for CI environments"""

    # Firefox options for CI environment
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1280,1024')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-plugins')
    options.add_argument('--disable-images')  # Speed up loading
    options.add_argument('--disable-javascript')  # Only if your accessibility scan doesn't need JS

    # Set preferences for better CI performance
    options.set_preference('dom.webdriver.enabled', False)
    options.set_preference('useAutomationExtension', False)
    options.set_preference('browser.startup.homepage', 'about:blank')
    options.set_preference('browser.startup.firstrunSkipped', True)
    options.set_preference('dom.disable_beforeunload', True)

    # Service configuration
    service = Service(
        executable_path='/usr/local/bin/geckodriver',
        log_path='/tmp/geckodriver.log'
    )

    # Desired capabilities for additional timeout control
    caps = DesiredCapabilities.FIREFOX.copy()
    caps['pageLoadStrategy'] = 'normal'  # or 'eager' for faster loading
    caps['timeouts'] = {
        'implicit': 30000,
        'pageLoad': 60000,
        'script': 30000
    }

    try:
        print("Creating Firefox WebDriver...")
        driver = webdriver.Firefox(
            service=service,
            options=options,
            desired_capabilities=caps
        )

        # Set additional timeouts
        driver.implicitly_wait(30)
        driver.set_page_load_timeout(60)
        driver.set_script_timeout(30)

        print("WebDriver created successfully!")
        return driver

    except Exception as e:
        print(f"Failed to create WebDriver: {e}")
        # Print geckodriver logs for debugging
        try:
            with open('/tmp/geckodriver.log', 'r') as f:
                print("GeckoDriver logs:")
                print(f.read())
        except:
            pass
        raise


def get_axe_results(driver):
    axe = Axe(driver)
    axe.inject()
    return axe.run({"runOnly": {"type": "tag", "values": TAGS}})


if __name__ == "__main__":
    scan_urls()
