# Windows Local Development

_This documentation is a work in progress._

The main README.md file covers local development for macOS and Linux. This guide provides Windows-specific setup instructions.

## Two Setup Options

We've tested two approaches for Windows development:

1. **Windows Subsystem for Linux (WSL)** - Simpler setup, but doesn't isolate the app from your system
2. **VS Code Dev Containers** - More complex setup, better isolation

## Option 1: Windows Subsystem for Linux (Recommended)

### Initial Setup

1. Follow the [Rails community WSL setup guide](https://gorails.com/setup/windows/11)
2. Use these specific versions:
    - Ruby 3.3.4
    - Node 23.4.0
3. **Stop before the "Final Steps" section** and follow the instructions below instead

### Rails Application Setup

**Prerequisites:**
- Clone the repository to your WSL home directory (this avoids file permission issues)
- Install Yarn: `npm install yarn -g`

**Configuration Steps:**

1. **Fix line endings for shell scripts:**
   ```bash
   # Convert Windows line endings to Unix for all scripts in bin/
   dos2unix bin/*
   ```

2. **Update database configuration:**
    - If your Postgres service was set up to allow "trust" authentication for local connections, you may not need to change anything. 
    - If you created a user with a password during database setup, add a username and password entry to the development section of `config/database.yml`. See the `staging` section for an example.


3. **Install dependencies and setup database:**
   ```bash
   bundle install
   rails db:migrate
   rails db:setup
   ```

4. **Start the application:**
   ```bash
   bin/dev
   ```

### Python Components and Localstack Setup

1. **Install Docker Desktop**

2. **Build and run containers:**
   ```bash
   # In your app directory
   docker compose build
   docker compose up
   ```

3. **Configure API credentials:**
   ```bash
   EDITOR="Your editor" rails credentials:edit --environment development
   ```
    - Set `api_user` and `api_password`
    - The default user from the [seeds file](../db/seeds.rb) works for local development

4. **Configure the Rails app:**
    - Visit http://localhost:3000/configuration/edit to complete setup

## Option 2: VS Code Dev Containers

This method provides better isolation but is more challenging to configure with the app's Lambda and Localstack containers.

**Getting Started:**
- Follow the [Rails Community dev container instructions](https://guides.rubyonrails.org/getting_started_with_devcontainer.html)

**Important:** The standard Rails guide doesn't cover our app's Lambda and Localstack containers, so you'll need to make additional changes outlined below.

### Required Configuration Changes

You'll need to modify several configuration files to get everything working properly:

#### 1. Update Node.js and Yarn Installation

Modify `.devcontainer/Dockerfile` to properly install Node.js and Yarn:

```dockerfile
FROM mcr.microsoft.com/devcontainers/ruby:1-3.3-bookworm

# Install Rails
RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

USER vscode
RUN bash -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts && npm install -g yarn"
```

#### 2. Configure Container Ports and Setup

Update `.devcontainer/devcontainer.json` to install gems and expose the ports needed by our containers:

```json
{
	"name": "Ruby on Rails & Postgres",
	"dockerComposeFile": "docker-compose.yml",
	"service": "app",
	"workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",

	// Use 'forwardPorts' to make a list of ports inside the container available locally.
	// This can be used to network with other containers or the host.
	"forwardPorts": [3000, 5432, 4566, 9002, 9003],

	// Use 'postCreateCommand' to run commands after the container is created.
	"postCreateCommand": "bundle install && bin/rails db:migrate && rake db:setup"
}
```

#### 3. Add All Required Services

Replace `.devcontainer/docker-compose.yml` with this configuration that includes all our app's containers:

```yaml
version: '3'

services:
  app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
    environment:
      - DATABASE_HOST=db
      - DATABASE_USER=postgres
      - DATABASE_PASSWORD=postgres
    volumes:
      - ../..:/workspaces:cached

    # Overrides default command so things don't shut down after the process ends.
    command: sleep infinity

    # Runs app on the same network as the database container, allows "forwardPorts" in devcontainer.json function.
    #network_mode: service:db

    # Use "forwardPorts" in **devcontainer.json** to forward an app port locally.
    # (Adding the "ports" property to this file will not forward from a Codespace.)
  db:
    image: postgres:latest
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./create-db-user.sql:/docker-entrypoint-initdb.d/create-db-user.sql
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
      POSTGRES_PASSWORD: postgres
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"  # LocalStack edge port
    environment:
      - SERVICES=s3,lambda,logs,secretsmanager
      - AWS_DEFAULT_REGION=us-east-1
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - ./tmp/localstack:/var/lib/localstack
      - /var/run/docker.sock:/var/run/docker.sock
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4566/_localstack/health"]
      interval: 5s
      timeout: 5s
      retries: 3
  setup:
    image: amazon/aws-cli:latest
    container_name: asap_setup
    environment:
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=none
      - AWS_SECRET_ACCESS_KEY=none
    volumes:
      - ../bin/setup-localstack:/setup-localstack
    entrypoint: ["/bin/bash", "/setup-localstack"]
    depends_on:
      localstack:
        condition: service_healthy
  lambda_document_inference:
    build:
      context: ../python_components/document_inference
    container_name: lambda_document_inference
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports:
      - "9002:8080"
    environment:
      - ASAP_LOCAL_MODE=True
    volumes:
      - ../python_components/document_inference:/var/task
  lambda_evaluation:
    container_name: lambda_evaluation
    build:
      context: ../python_components/evaluation
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports:
      - "9003:8080"
    environment:
      - ASAP_LOCAL_MODE=True
    command: [ "lambda_function.handler" ]
    entrypoint: ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
    volumes:
      - ../python_components/evaluation:/var/task

volumes:
  postgres-data:
```

#### 4. Update Database Configuration

Modify `config/database.yml` to use the database credentials and host defined in the docker-compose.yaml file above.

#### 5. Update Service References

Search through your `app` and `config` directories for any references to `localhost` and change them to use the appropriate service names for development. You can see examples of these changes in [this branch](https://github.com/codeforamerica/asap_pdf/compare/1337-windows-devcontainers).

#### 6. Configure API Credentials

From the VS Code terminal, set up your API credentials:

```bash
EDITOR="Your editor" rails credentials:edit --environment development
```
- Set `api_user` and `api_password`
- The default user from the [seeds file](../db/seeds.rb) works for local development