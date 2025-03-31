FROM python:latest
COPY requirements.txt .
ENV PYTHONPATH=\/workspace
RUN pip install -r requirements.txt --trusted-host pypi.python.org --no-cache-dir
#RUN deepeval set-ollama gemma3 --base-url="http://evaluation_ollama:11434"
WORKDIR /workspace