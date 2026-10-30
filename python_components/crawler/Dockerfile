FROM python:3.14.6@sha256:5f1cdbcab9a50594a79502dd73e885456d2a2fc31f1a1fa18484815b37ee9152
ENV PYTHONPATH=\/workspace
WORKDIR /workspace

RUN apt-get update && apt-get install -y \
    firefox-esr \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/geckodriver.tar.gz https://github.com/mozilla/geckodriver/releases/download/v0.33.0/geckodriver-v0.33.0-linux64.tar.gz \
    && tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/geckodriver

COPY requirements.txt .
RUN pip install -r requirements.txt --trusted-host pypi.python.org --no-cache-dir
