# Build context is mocks/ so the demo sites are served by the same small service.
FROM ruby:3.4-slim
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends build-essential curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY company-backend/Gemfile company-backend/Gemfile.lock* ./
RUN bundle install --jobs 4
COPY company-backend/ .
COPY demo-sites/ ./public/sites/
EXPOSE 4567
CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "4567"]
