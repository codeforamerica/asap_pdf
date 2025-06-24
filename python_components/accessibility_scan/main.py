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
)


def scan_urls():
    # Automatically manage geckodriver
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

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
    """Create a Firefox WebDriver configured for CI/headless environment"""

    # Firefox options for CI environment
    options = Options()

    # Essential headless options
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1280,1024')
    options.add_argument('--disable-web-security')
    options.add_argument('--disable-features=VizDisplayCompositor')

    # CI-specific Firefox preferences
    preferences = {
        # Disable caching
        'browser.cache.disk.enable': False,
        'browser.cache.memory.enable': False,
        'browser.cache.offline.enable': False,

        # Disable session restore and startup
        'browser.sessionstore.resume_from_crash': False,
        'browser.startup.page': 0,
        'browser.startup.homepage': 'about:blank',

        # Disable tabs and process isolation (helps in CI)
        'browser.tabs.remote.autostart': False,
        'browser.tabs.remote.autostart.2': False,
        'dom.ipc.processCount': 1,

        # Disable sandbox (often needed in CI)
        'security.sandbox.content.level': 0,
        'security.sandbox.gpu.level': 0,

        # Disable various features that can cause issues
        'browser.safebrowsing.enabled': False,
        'browser.safebrowsing.malware.enabled': False,
        'browser.safebrowsing.phishing.enabled': False,
        'datareporting.healthreport.uploadEnabled': False,
        'datareporting.policy.dataSubmissionEnabled': False,
        'toolkit.telemetry.enabled': False,
        'toolkit.telemetry.unified': False,

        # Media and WebRTC
        'media.navigator.enabled': False,
        'media.peerconnection.enabled': False,
        'media.autoplay.default': 2,

        # Notifications and geolocation
        'dom.webnotifications.enabled': False,
        'geo.enabled': False,

        # Disable automatic updates
        'app.update.enabled': False,
        'app.update.auto': False,

        # Network settings
        'network.http.phishy-userpass-length': 255,
        'network.manage-offline-status': False,

        # Accessibility (don't disable - we need this for axe)
        'accessibility.force_disabled': 0,
    }

    # Apply all preferences
    for key, value in preferences.items():
        options.set_preference(key, value)

    # Service configuration
    service_args = [
        '--log=debug',  # Enable debug logging
        '--marionette-port=2828',  # Explicit port
    ]

    try:
        service = Service(
            executable_path='/usr/local/bin/geckodriver',
            service_args=service_args
        )

        print("Creating Firefox WebDriver...")
        driver = webdriver.Firefox(service=service, options=options)

        # Set timeouts
        driver.set_page_load_timeout(30)
        driver.implicitly_wait(10)

        print("Firefox WebDriver created successfully")
        return driver

    except Exception as e:
        print(f"Failed to create Firefox WebDriver: {str(e)}")
        raise

def get_axe_results(driver):
    axe = Axe(driver)
    axe.inject()
    return axe.run({"runOnly": {"type": "tag", "values": TAGS}})


if __name__ == "__main__":
    scan_urls()
