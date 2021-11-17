SHELL := /bin/bash

OUT_DIR = $(CURDIR)/build/_output/

all: build-manifests test

test:
	./tests/test-coreos.sh

build-manifests:
	./hack/build-manifests.sh ${OUT_DIR}

.PHONY: \
	test \
	build-manifests \
