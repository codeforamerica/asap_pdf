FROM python:3.12
COPY ./scripts/entrypoint.sh /usr/local/bin
COPY requirements.txt .
ENV PYTHONPATH=\/workspace
RUN pip install -r requirements.txt --trusted-host pypi.python.org --no-cache-dir &&\
    python -m spacy download en_core_web_sm
WORKDIR /workspace
ENTRYPOINT ["entrypoint.sh"]