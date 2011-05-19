#!/usr/bin/env bash
if [ "$RACK_ENV" = "production" ]; then
  export JRUBY_OPTS="--1.9 --server --headless"
  export PATH=/opt/jruby/bin:$PATH
  jruby -S bundle exec trinidad --config
else
  jruby --1.9 --server -S trinidad --config
fi
