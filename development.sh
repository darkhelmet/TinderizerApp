#!/usr/bin/env bash
export JRUBY_OPTS="--1.9 --client -J-Djruby.reify.classes=true -J-Xmx1024m -J-XX:+UseConcMarkSweepGC -J-XX:+UseParNewGC"
jruby -S trinidad --config
