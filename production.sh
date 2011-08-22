#!/usr/bin/env bash
export RACK_ENV=production
export JRUBY_OPTS="--1.9 --server --headless -J-Djruby.reify.classes=true -J-Xmx768m -J-XX:+UseConcMarkSweepGC -J-XX:+UseParNewGC -J-XX:+HeapDumpOnOutOfMemoryError"
export PATH=/opt/jruby/bin:$PATH
yui-compressor public/bookmarklet.js > public/bookmarklet.min.js
jruby -S bundle exec trinidad --env production --config
