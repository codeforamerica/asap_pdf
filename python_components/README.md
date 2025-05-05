# Python Components

The components in this directory cover various document handling processes. They are intended to be run in AWS Lambda functions in Docker containers. Each component should contain a Lambda entry point (Python script), requirements.txt and Dockerfile minimally.

For local development, Lambda compatible components should be setup automatically by running `docker compose up` in the project root. Lambda functions should return JSON responses with `statusCode` and `body` keys.

To set API keys for AI services, visit the application configuration page. API keys are saved to the localstack version of AWS Secretes Manager.

## Codestyle

The Python components should be PEP8 compliant. They are currently linted with isort, black and flake8 with discrete budgets via Github Actions. To reproduce the CI output directly, from the python_components directory build the CI image locally `docker build -t asap_pdf:ci .` and run `docker run --rm -v ./:/workspace asap_pdf:ci scripts/ci_run_linting.sh "**/*.py"`.

Or the `scripts/local_fix_linting.sh` was included to help fix codestyle issues locally.


## Document Inference

The document inference python component handles a variety of document-related AI inquiries including summarization and exception suggestion. Additional inference types may be added by adding prompts and models the included library. Responses are transmitted to the ASAP API document_inferences endpoint.

## Evaluation

The evaluation component contains a suite of tools for running automated and consistent metrics on our AI powered systems. It is intended to be used as an ad hoc, Github Action (.github/workflows/eval.yml). The action builds both the evaluation and document inference containers with a provided branch. The images are pushed to AWS Elastic Container Registry (ECR) and assigned to two evaluation lambdas, where the suite is executed. Output is dumped to S3 as a csv by default.

The evaluation suite may be run locally as well. It communicates with the document inference container and requires that environment to be configured and functional.

For local development (3 proceses required):
- From the project root run `docker compose build --no-cache`
- Run the rails app `bin/rails`
- Run commands via curl.

Sample curl command:
```shell
curl "http://localhost:9003/2015-03-31/functions/function/invocations" -d '{"evaluation_model": "gemini-2.5-pro-preview-03-25", "inference_model": "gemini-1.5-pro-latest", "page_limit": 7, "documents": [{"file_name": "MINUTES%20December%202024.pdf", "category": "Agenda", "url": "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "human_summary": "Minutes for a December 12 2024 meeting of the Georgia Structural Pest Control Commission. During the meeting there were updates from the UGA Urban Entomology, Compliance and Enforcement, Certification and Training, among others."}], "branch_name": "foo", "commit_sha": "123"}'
```

## TODO

* Include unit tests when it makes sense.
* Pull down documents from S3, rather than http request to gov website.
