# V pcre2 module

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := build
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:
.SILENT:

.PHONY: test build fmt docs run-examples tag push

test:
	v -cstrict test .

fmt:
	v fmt -w *.v examples/*.v

build: fmt test docs
	# Can't use -cstrict (see https://github.com/vlang/v/issues/16016)
	v -cc gcc -prod examples/pcre2-example-1.v

docs:
	v doc -f html -readme -o docs .
	v check-md README.md

run-examples:
	echo
	echo "NOTE: runs examples using installed 'srackham.pcre2' module"
	echo
	bash -c 'cd examples && for f in pcre2-example-*.v; do v -cstrict run $$f; done'

tag: test
	tag=$(VERS)
	echo tag: $$tag
	git tag -a -m "$$tag" "$$tag"

push: test
	git push -u --tags origin master
