# TODO

ASAP PDF is a work in progress. Here are some upcoming goals.

## Rails APP
* Store documents in S3 instead of requesting every time, ideally preprocess PDFs as images
* Enable backend processing, queue up and bulk process documents via Sidekiq and Redis

## Python Components
* Add HTML conversion
* Explore and implement an accessibility remediation/assessment strategy
* Add evaluation metrics for any new features