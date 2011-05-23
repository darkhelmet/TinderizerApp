#!/usr/bin/env bash
scalac -deprecation -cp lib/jsoup-1.5.2.jar:vendor/goose/target/classes -d classes lib/scala/*.scala
