SHELL := /bin/sh
NPM ?= npm

.PHONY: help install test test-stack compile lint clean deploy

help:
	@printf "Available targets:\n"
	@printf "  install     Install npm dependencies\n"
	@printf "  test        Run the Hardhat test suite\n"
	@printf "  test-stack  Run tests with stack traces enabled\n"
	@printf "  compile     Compile smart contracts\n"
	@printf "  lint        Lint Solidity contracts\n"
	@printf "  clean       Remove generated build artifacts\n"
	@printf "  deploy      Deploy to the local test network\n"

install:
	$(NPM) install

test:
	$(NPM) test

test-stack:
	$(NPM) run test:stack

compile:
	$(NPM) run compile

lint:
	$(NPM) run lint

clean:
	$(NPM) run clean

deploy:
	$(NPM) run deploy
