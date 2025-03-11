FROM public.ecr.aws/lambda/python:3.12

# Copy requirements.txt & config.json
COPY requirements.txt ${LAMBDA_TASK_ROOT}
COPY 2025-03-11-56-llm-gemini.patch ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN dnf install poppler-utils git-all -y &&\
    pip install -r requirements.txt &&\
    git clone https://github.com/simonw/llm-gemini.git &&\
    mv 2025-03-11-56-llm-gemini.patch llm-gemini &&\
    cd llm-gemini &&\
    git apply 2025-03-11-56-llm-gemini.patch &&\
    llm install -e '.[test]' &&\
    mkdir ${LAMBDA_TASK_ROOT}/data

# Copy application config
COPY config.json ${LAMBDA_TASK_ROOT}

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]
