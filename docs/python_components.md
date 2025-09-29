# Python Components

The document crawler and classification components are currently used manually. Their containers are built from the Python base image. The document inference and evaluation components are meant to be executed as AWS Lambda functions. Their containers are built from the Amazon Lambda Python Base images.

For local development, Lambda compatible components should be setup automatically by running `docker compose up` in the project root. Lambda functions should return JSON responses with `statusCode` and `body` keys.

To set API keys for AI services, visit the application configuration page. API keys are saved to the localstack version of AWS Secretes Manager.

## Prerequisites
- Docker and Docker Compose
- Google Cloud account with access to Gemini API or Anthropic account with API access.

## Code style

The Python components should be PEP8 compliant. They are currently linted with isort, black and flake8 with discrete budgets via Github Actions. To reproduce the CI output directly, from the python_components directory build the CI image locally `docker build -t asap_pdf:ci .` and run `docker run --rm -v ./:/workspace asap_pdf:ci scripts/ci_run_linting.sh "**/*.py"`.

Or the `scripts/local_fix_linting.sh` was included to help fix codestyle issues locally.

## Crawling and classification

Two python components run as needed, usually when we're onboarding a new partner. The crawling component can be run by initializing the docker container with `docker run --rm -it -v "$(pwd):/workspace" asap_pdf:crawler bash`, adding any new sites to `crawler/config.json`, and running the script with `python crawler.py <site_url> <output_path>`. There is an optional delay argument to add time between requests.

The classification python component can be run by initializing the docker container (`docker run --rm -it -v "$(pwd):/workspace" asap_pdf:classifier bash`), and then running the script with `python crawler.py <input_path> <labeled_output_path>`. The script expects the input CSV to have the same format as the output of the crawling script.

After running these scripts, the output from the classification component can be used to update the production data at `site_documents.zip`. Use the `split_for_dev.py` script to randomly sample among the production data, and update `site_documents_dev.zip` with those sampled datasets.

### Helper Script

A shell script has been included that combines the crawling and classification steps. You can find it in [bin/crawl](../bin/crawl). Before running the script add entries to [../python_components/crawler/config.json](crawler/config.json).

Sample usage:

```
bin/crawl <url from config.json> <path to csv data> <optional path to previous crawl csv data for comparison>
```

## Document Inference

The document inference python component handles a variety of document-related AI inquiries including summarization and exception suggestion. Additional inference types may be added by adding prompts and models the included library. Responses are transmitted to the ASAP API document_inferences endpoint.

## Evaluation

The evaluation component contains a suite of tools for running automated and consistent metrics on our AI powered systems. It is intended to be used as an ad hoc, Github Action (.github/workflows/eval.yml). The action builds both the evaluation and document inference containers with a provided branch. The images are pushed to AWS Elastic Container Registry (ECR) and assigned to two evaluation lambdas, where the suite is executed. Output is dumped to S3 as a csv by default.

The evaluation suite may be run locally as well. It communicates with the document inference container and requires that environment to be configured and functional.

For local development (three shell processes are required):
- From the project root run `docker compose build --no-cache`
- Then run `docker compose up`
- In a new process run the rails app `bin/rails`
- In a final process, run commands via curl (see below).

Sample curl command:
```shell
curl "http://localhost:9003/2015-03-31/functions/function/invocations" -d '{"evaluation_model": "gemini-2.5-pro-preview-03-25", "inference_model": "gemini-1.5-pro-latest", "page_limit": 7, "documents": [{"file_name": "MINUTES%20December%202024.pdf", "category": "Agenda", "url": "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "human_summary": "Minutes for a December 12 2024 meeting of the Georgia Structural Pest Control Commission. During the meeting there were updates from the UGA Urban Entomology, Compliance and Enforcement, Certification and Training, among others."}], "branch_name": "foo", "commit_sha": "123"}'
```
