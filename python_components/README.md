# Python Components

The components in this directory cover various document handling processes. They are intended to be run in AWS Lambda functions in Docker containers. Each component should contain a Lambda entry point (Python script), requirements.txt and Dockerfile minimally.

For local development, Lambda compatible components should be setup automatically by running `docker compose up` in the project root. Lambda functions should return JSON responses with `statusCode` and `body` keys.

To set API keys for AI services, visit the application configuration page. API keys are saved to the localstack version of AWS Secretes Manager.

## Codestyle

The Python components should be PEP8 compliant. They are currently linted with isort, black and flake8 with discrete budgets via Github Actions. To reproduce the CI output directly, from the python_components directory build the CI image locally `docker build -t asap_pdf:ci .` and run `docker run --rm -v ./:/workspace asap_pdf:ci scripts/ci_run_linting.sh "**/*.py"`.

Or the `scripts/local_fix_linting.sh` was included to help fix codestyle issues locally.


## Document Inference

The document inference python component handles a variety of document-related AI inquiries including summarization and exception suggestion. Additional inference types may be added by adding prompts and models the included library. Responses are transmitted to the ASAP API document_inferences endpoint.

## TODO

* Include unit tests when it makes sense.
* Pull down documents from S3, rather than http request to gov website.
* Build remaining components.
* Add prototype of LLM evaluation
