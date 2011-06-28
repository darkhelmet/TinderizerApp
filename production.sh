#!/usr/bin/env bash
export RACK_ENV=production
export JRUBY_OPTS="--1.9 --server --headless -J-Djruby.reify.classes=true -J-Xmx1024m -J-XX:+UseConcMarkSweepGC -J-XX:+UseParNewGC"
export PATH=/opt/jruby/bin:$PATH
jruby -S bundle exec trinidad --env production --config
