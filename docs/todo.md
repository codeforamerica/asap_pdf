# TODO

ASAP PDF is a work in progress. Here are some upcoming goals.

## Rails APP
* Improved user and site management, including many to many user-site relationships
* Accessibility audit and improvements
* Store documents in S3 instead of requesting every time, ideally preprocess PDFs as images
* Enable backend processing, queue up and bulk process documents via Sidekiq and Redis

## Python Components
* Add evaluation metrics for Accessibility check
* Refactor and tune Accessibility check
* Add evaluation metrics for HTML conversion
* Add HTML conversion
* Explore and implement an accessibility remediation/assessment strategy
