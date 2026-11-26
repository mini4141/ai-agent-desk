# syntax=docker/dockerfile:1
FROM ruby:3.4-slim AS base
ENV BUNDLE_PATH=/usr/local/bundle LANG=C.UTF-8 RUBY_YJIT_ENABLE=1
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    build-essential libpq-dev libyaml-dev git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4
COPY . .
ENV RAILS_ENV=production
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
