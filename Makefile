PROG_NAME=olm-mermaid-graph
#OUTPUT_TYPE=png # or pdf
OUTPUT_TYPE=svg
MERMAID_TEMP_SCRIPT=mermaid.mer
CONTAINER_ENGINE?=docker

# commented out versions show various options for defining this variable,
#   including pointing it at an index file created for your operator locally (see README-local-package-graph.md)
#INDEX_DB_PATH_AND_NAME?=/Users/btofel/workspace/sample-operator/test-registry.db
#INDEX_DB_PATH_AND_NAME?=olm_catalog_indexes/index.db.4.6.community-operators
INDEX_DB_PATH_AND_NAME?=olm_catalog_indexes/index.db.4.6.redhat-operators

detected_OS := $(shell uname 2>/dev/null || echo Unknown)

.PHONY: all
all: build

.PHONY: build
build:
	go build -o bin/$(PROG_NAME) ./

.PHONY: install
install:
	go install

run: build
	sed 's+olm_catalog_indexes/index.db.4.6.redhat-operators+$(INDEX_DB_PATH_AND_NAME)+' sqlite3.sql > sqlite3_exec.sql
	sqlite3 -bail -init sqlite3_exec.sql 2>/dev/null | bin/$(PROG_NAME) $(ARGS) 1>$(MERMAID_TEMP_SCRIPT)
	$(CONTAINER_ENGINE) pull minlag/mermaid-cli
	$(CONTAINER_ENGINE) run \
		--user 10001:10001 \
		-v $(PWD)/$(MERMAID_TEMP_SCRIPT):/$(MERMAID_TEMP_SCRIPT) \
		-v $(PWD)/config.json:/config.json \
		-v /tmp:/.cache/yarn \
		-v /tmp:/.yarn \
		-v /tmp:/tmp -it \
		docker.io/minlag/mermaid-cli:20210503120233a6e5e8 \
		-c /config.json -i /$(MERMAID_TEMP_SCRIPT) -o /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)
	echo "output $(OUTPUT_TYPE) file is /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)"
ifeq ($(detected_OS),Darwin)
	open /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)
endif

.PHONY: clean
clean:
	rm -r bin
	rm mermaid.mer
	rm /tmp/mermaid.mer.png

