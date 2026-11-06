# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker login dhi.io
# docker build --platform linux/amd64 -t asap_pdf .
# docker run -d -p 3000:3000 -e RAILS_MASTER_KEY=<value from config/master.key> --name asap_pdf asap_pdf

# Based on https://docs.docker.com/guides/ruby/
#
# Uses Docker Hardened Images (DHI): https://docs.docker.com/dhi/
# DHI images are not public. Run `docker login dhi.io` with Docker Hub
# credentials before building locally.
#
# Base images are pinned by tag rather than digest so every build picks up the
# latest patched base for these Ruby and Node versions.

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.12
# Make sure NODE_VERSION matches the Node version in .node-version
ARG NODE_VERSION=24.22.1

# Node is only needed to compile assets. The build stage copies it from this
# image; nothing from it reaches the final image.
FROM dhi.io/node:$NODE_VERSION-dev AS node

FROM dhi.io/ruby:$RUBY_VERSION-dev AS base

# Rails app lives here
WORKDIR /rails

# Install base packages. Runtime only. The hardened base already ships both of
# these; they're listed so the app's dependency on them is explicit:
# - ca-certificates: TLS to AWS, SMTP, and LLM APIs.
# - libjemalloc2: preloaded by bin/docker-entrypoint.
# Not installed: curl (the load balancer health-checks /up), libvips (the app
# doesn't process images), sqlite3 (the app uses PostgreSQL), libpq5 (the
# precompiled pg gem bundles its own libpq).
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y ca-certificates libjemalloc2 && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
  BUNDLE_DEPLOYMENT="1" \
  BUNDLE_PATH="/usr/local/bundle" \
  BUNDLE_WITHOUT="development:test"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y build-essential git pkg-config libpq-dev libyaml-dev && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js and Yarn from the hardened Node image. It ships Yarn 1, which
# matches yarn.lock. Tailwind comes from the app's own node modules.
COPY --from=node /usr/bin/node /usr/bin/node
COPY --from=node /usr/lib/nodejs /usr/lib/nodejs
RUN ln -s ../lib/nodejs/yarn/bin/yarn /usr/bin/yarn && \
  node --version && yarn --version

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
  rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
  bundle exec bootsnap precompile --gemfile

# Install node modules
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Node modules and their manifests are only needed to compile assets. Removing
# the manifests also keeps image scanners from reporting packages that never
# run in production.
RUN rm -rf node_modules package.json yarn.lock


# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security. This is
# the hardened base's built-in nonroot user (UID 65532), so no user-management
# packages need to be installed. The base gives nonroot the gem directory, which
# is also Bundler's config directory (BUNDLE_APP_CONFIG); hand it back to root so
# the app can't change its own gems or Bundler settings.
RUN chown -R nonroot:nonroot db log storage tmp bin && \
  chown root:root "${BUNDLE_PATH}"
USER 65532:65532

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]
