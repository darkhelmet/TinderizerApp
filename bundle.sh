#!/usr/bin/env bash
export JRUBY_OPTS="--1.9 --server --headless"
export PATH=/opt/jruby/bin:$PATH
jruby -S bundle --deployment
