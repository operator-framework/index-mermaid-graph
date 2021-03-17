PROG_NAME=olm-mermaid-graph
#OUTPUT_TYPE=png # or pdf
OUTPUT_TYPE=svg
MERMAID_TEMP_SCRIPT=mermaid.mer
#INDEX_DB_PATH_AND_NAME?=/Users/btofel/workspace/sample-operator/test-registry.db
#INDEX_DB_PATH_AND_NAME?=olm_catalog_indexes/index.db.4.6.community-operators
INDEX_DB_PATH_AND_NAME?=olm_catalog_indexes/index.db.4.6.redhat-operators

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
	docker pull minlag/mermaid-cli
	docker run \
		-v $(PWD)/$(MERMAID_TEMP_SCRIPT):/$(MERMAID_TEMP_SCRIPT) \
		-v $(PWD)/config.json:/config.json \
		-v /tmp:/tmp -it \
		docker.io/minlag/mermaid-cli:latest \
		-c /config.json -i /$(MERMAID_TEMP_SCRIPT) -o /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)
	echo "output $(OUTPUT_TYPE) file is /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)"
	open /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)

.PHONY: clean
clean:
	rm -r bin
	rm mermaid.mer
	rm /tmp/mermaid.mer.png

