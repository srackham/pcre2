# V pcre2 module

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := build
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:
# .SILENT:

.PHONY: test build docs run-examples

test:
	v -cstrict test .
	make run-examples

build: test docs
	v fmt -w *.v examples/*.v

docs:
	v doc -f html -readme -o docs .

run-examples:
	bash -c 'cd examples && for f in pcre2-example-*.v; do v -cstrict run $$f; done'