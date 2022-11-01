# V pcre2 module

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := build
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:
# .SILENT:

.PHONY: test build fmt docs run-examples

test:
	v -cstrict test .
	make run-examples

fmt:
	v fmt -w *.v examples/*.v

build: fmt test docs
	# Can't use -cstrict (see https://github.com/vlang/v/issues/16016)
	#v -cc gcc -cstrict -prod examples/pcre2-example-1.v
	v -cc gcc -prod examples/pcre2-example-1.v

docs:
	v doc -f html -readme -o docs .
	v check-md README.md

run-examples:
	bash -c 'cd examples && for f in pcre2-example-*.v; do v -cstrict run $$f; done'