#!/usr/bin/env bash
export RACK_ENV=production
export JRUBY_OPTS="--1.9 --server --headless"
export PATH=/opt/jruby/bin:$PATH
jruby -S bundle exec trinidad --env production --config
