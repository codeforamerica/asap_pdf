# ASAP PDF

A Rails application for navigating PDF accessibility audits. We use traditional NLP and LLM processes to prioritize and
stratify documents, guiding stakeholders through corrective action decision-making. For additional documentation, see the [docs](./docs) folder.

Features:
- Scrape websites for PDF documents and harvest metadata
- Use NLP to classify documents by category
- Dashboards and audit workflow to help navigate decision-making
- LLM-powered tools to summarize and perform policy analysis on documents

## Contact
Fill out [this Google Form](
https://docs.google.com/forms/d/e/1FAIpQLSf2C4uKOgCTf-nrBM7bBWRSyNDELhE6c6EaHMN5Or71vyd7fw/viewform) to connect with Code for America and learn more.

## Architecture
ASAP has two major architectural realms, a Ruby on Rails powered user interface and [Python components](docs/python_components.md), which provide many of the document processing and AI features. The Rails-based UI is not required. The Python components may each be used as standalone services.

### Ruby on Rails Application (Audit UI)
- **Frontend**: Hotwired (Turbo + Stimulus) with Tailwind CSS
- **Backend**: Ruby on Rails 8.0
- **Database**: PostgreSQL
- **Testing**: RSpec and Capybara

### Python Components

The application includes several Python components for PDF processing:

- **Site Crawler**: Downloads PDF files and metadata from government websites
- **Document Classifier**: Determines document types using machine learning
- **Document Inference**: Generates LLM summaries and performs exception checks
- **Evaluation**: Automated LLM evaluation suite

For detailed information about the Python components, see the [Python Components documentation](docs/python_components.md). Architectural diagrams are available in the [Architecture documentation](docs/architecture.md).

## Getting Started
The following instructions are intended for local development on macOS or Linux environments. To run the app locally on Windows follow [the Windows setup guide](docs/windows_localdev.md) instead. The [staging and production documentation](docs/deployment.md) details running the app on Amazon Web Services (AWS), however any cloud hosting platform should be possible.

### Prerequisites

Before you begin, ensure you have the following installed:

* Ruby 3.3.4 (we recommend using a version manager like `rbenv` or `rvm`)
* Node.js 24.4.1 (we recommend using `nvm` for version management)
* Yarn (latest version)
* PostgreSQL locally or in a container
* Docker and Docker Compose (for LocalStack AWS services in development)
* Optional, to use the LLM features, API credentials for Google, Anthropic or OpenAI

### Running the App
To run all the App's features, you will need to run the Rails application and Python components in separate terminal processes. For simplicity’s sake, we run the Rails application locally (on the host machine), while the Python components run in a Docker Compose (see [docker-compose.yml](docker-compose.yml)). For the LLM features to function correctly, credentials must be added to the Rail UI while the Python components are running. This simulates the production environment most directly. 

#### Set up the Rails App 

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

4. Set up the database:
   ```bash
    rails db:migrate ; rails db:setup
   ```

5. Test running the app:

   ```bash
   bin/dev
   ```

6. A default admin user was created during database setup. See [seeds.rb](db/seeds.rb) for details. To add your own admin user, run the following rake task:
   ```bash
   rake users:create_admin"[<your email>,<your password>]"
   ```
   
7. Add admin credentials for API usage by Python components. For local development, add admin credentials to the development configuration as `api_user` and `api_password`.
   ```bash
   `EDITOR="Your editor" rails credentials:edit --environment development`
   ```
   The final configuration should look something like:
   ```yaml
   api_user: <your email>
   api_password: <your password>
   ```

#### Set up the Python Components

1. From the project root, build images
   ```bash
   docker compose build
   ```
2. Start the containers
   ```bash
   docker compose up
   ```
3. In a separate terminal process, run the Rails app.
   ```bash
   bin/dev
   ```
4. Log into the app, visit `/configuration/edit`. Enter just LLM API credentials you'd like to use and save the form. The credentials are ephemerally stored in the LocalStack clone of AWS SecretsManager. If you restart the Docker containers, the API credentials must be reentered.

## Adding Sites, Documents and Users

When the database is set up (`bin/rails db:setup`), it is populated with some sample sites, sandbox documents and an admin user.

### Adding Users
- Admin users may be created via the admin user rake task: `bin/rake users:create_admin"[<email>, <password>]"`
- To create non-admin users, log into the app with an admin user and use the administrative user interface at `/admin/users`.

### Adding Sites
- After logging in, sites may be added by "Site Admin" users through the UI on the `/sites` page.

### Adding Documents
- Documents may be imported via the document import rake task: `bin/rake documents:import_documents"[<site id>, <path to csv>, <archive bool*>]"`
- Sample csv documents may be found in db/seeds. The format should match the output of the crawl and classification processes. Check out the documentation in [the python_components directory](docs/python_components.md) for more details.

*Set to true to import a csv inside a zip archive.

Users, Sites and Documents may be added manually via the Rails console as well.

## License

This project's code is licensed under the Apache 2.0 License. All assets, such as images provided by Code for America are licensed under the CC-BY-4.0 license. 
