FROM public.ecr.aws/lambda/python:3.12

# Copy requirements.txt & config.json
COPY requirements.txt ${LAMBDA_TASK_ROOT}
COPY config.json ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN dnf install poppler-utils -y &&\
  pip install -r requirements.txt &&\
  mkdir ${LAMBDA_TASK_ROOT}/data

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]
