# ASAP PDF

A Rails application for navigating PDF Accessibility audits. We use traditional NLP and LLM processes to prioritize and
stratify documents, guiding stakeholders through corrective action decision-making. In the future we hope to build in
more accessibility auditing and remediation. For additional documentation, see the [docs](./docs) folder.

Fill out [this Google Form](
https://docs.google.com/forms/d/e/1FAIpQLSf2C4uKOgCTf-nrBM7bBWRSyNDELhE6c6EaHMN5Or71vyd7fw/viewform) to connect with Code for America and learn more.

## Prerequisites

Before you begin, ensure you have the following installed:

* Ruby 3.2.2 (we recommend using a version manager like `rbenv` or `rvm`)
* Node.js 18.17.0 (we recommend using `nvm` for version management)
* Yarn (latest version)
* Redis (for Sidekiq background jobs)
* PostgreSQL locally or in a container.
* Docker and Docker Compose (for LocalStack S3 in development)

## Rails App Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/codeforamerica/asap_pdf.git
   cd asap_pdf
   ```

2. Install Ruby dependencies:
   ```bash
   bundle install
   ```

3. Install JavaScript dependencies:
   ```bash
   yarn install
   ```

4. Setup the database:
   ```bash
   bin/rails db:setup
   ```

## Running the Application

Start the development server and all required processes:

```bash
bin/dev
```

This command starts the following processes (defined in `Procfile.dev`):

- Rails server
- JavaScript build process (with esbuild)
- CSS build process (with Tailwind CSS)
- Sidekiq worker for background jobs

The application will be available at http://localhost:3000

## Architecture Overview

- **Frontend**: Built with Hotwired (Turbo + Stimulus) and Tailwind CSS
- **Backend**: Ruby on Rails 7.0
- **Background Jobs**: Sidekiq with Redis
- **Testing**: RSpec

## Python Components

The application includes several Python components for PDF processing:

- Site Crawler: Downloads PDF files and their metadata from government websites
- Document Classifier: Determines document types using ML
- Document Inference: LLM summary and exception check
- Evaluation: Automated LLM evaluation suite.

To set up the Python components, follow [these instructions](python_components/README.md).

## Testing

Run the test suite:

```bash
bundle exec rails test:prepare
bundle exec rspec
```

## Development Tools

The project includes several development tools:

- **Brakeman**: Security analysis (`bin/brakeman`)
- **RuboCop**: Code style checking (`bin/rubocop`)
- **Overcommit**: Git hooks management
- **Better Errors**: Enhanced error pages in development
- **Bullet**: N+1 query detection

## API

Some basic API endpoints are currently provided.

### Sites API (v1)

- `GET /api/v1/sites`
    - Lists all sites
    - Returns site details excluding user_id, created_at, updated_at
    - Includes s3_endpoint for each site

- `GET /api/v1/sites/:id`
    - Retrieves a specific site
    - Returns site details excluding user_id, created_at, updated_at
    - Includes s3_endpoint

### Document Inference (v1)

- `POST /api/v1/documents/inference`
    - Adds or updates a document inference record.
    - Ideally used for storing AI results for documents.

## Contributing

1. If contributing in Ruby, ensure all tests pass and no new RuboCop violations are introduced. If contributing in
   Python, ensure all tests pass and that no new python linting violations are introduced.
2. Update documentation as needed
3. Follow the existing code style and conventions

## License

This project's code is licensed under the Apache 2.0 License. All assets, such as images provided by Code for America are licensed under the CC-BY-4.0 license. 
