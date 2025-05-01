FROM public.ecr.aws/lambda/python:3.12

# Prevent LLM module from writing (?) to a directory Lambda doesn't like.
ENV LLM_USER_PATH=/tmp
# Prevent deep eval from writing telemetry file.
ENV DEEPEVAL_TELEMETRY_OPT_OUT="YES"
# Try to stop transformers from writing to the RO file sytem.
ENV TRANSFORMERS_CACHE=/tmp
ENV HF_HOME=/tmp

# Copy requirements.txt & config.json
COPY requirements.txt ${LAMBDA_TASK_ROOT}
COPY models.json ${LAMBDA_TASK_ROOT}
COPY pyproject.toml ${LAMBDA_TASK_ROOT}
COPY evaluation ${LAMBDA_TASK_ROOT}/evaluation

# Install the specified packages
RUN dnf install poppler-utils -y &&\
  pip install -r requirements.txt &&\
  mkdir ${LAMBDA_TASK_ROOT}/data

RUN pip install .

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]
