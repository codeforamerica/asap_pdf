FROM public.ecr.aws/lambda/python:3.12

# Prevent LLM module from writing (?) to a directory Lambda doesn't like.
ENV LLM_USER_PATH=/tmp
# Prevent deep eval from writing telemetry file.
ENV DEEPEVAL_TELEMETRY_OPT_OUT="YES"
# Try to stop transformers from writing to the RO file sytem.
ENV TRANSFORMERS_CACHE=/tmp
ENV HF_HOME=/tmp

WORKDIR ${LAMBDA_TASK_ROOT}

# Copy requirements.txt & config.json
COPY requirements.txt .

# Install the specified packages
RUN dnf install poppler-utils git -y &&\
  pip install -r requirements.txt &&\
  python -m spacy download en_core_web_sm

COPY models.json .
COPY pyproject.toml .
COPY evaluation ./evaluation
COPY lambda_function.py .
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN pip install --no-cache-dir .

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]
