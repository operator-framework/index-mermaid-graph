PROG_NAME=olm-mermaid-graph
#OUTPUT_TYPE=png # or pdf
OUTPUT_TYPE=svg
MERMAID_TEMP_SCRIPT=mermaid.mer
#TODO: added a workaround (htmlabels: true in config.json) to allow `latest` tag until https://github.com/mermaid-js/mermaid-cli/issues/266 is fixed
MERMAID_IMAGE=docker.io/minlag/mermaid-cli:latest
CONTAINER_ENGINE?=docker
IMAGE?=registry.redhat.io/redhat/redhat-operator-index:v4.7

# commented out versions show various options for defining this variable,
#   including pointing it at an index file created for your operator locally (see README-local-package-graph.md)
#INDEX_DB_PATH_AND_NAME?=/Users/btofel/workspace/sample-operator/test-registry.db
#INDEX_DB_PATH_AND_NAME?=olm_catalog_indexes/index.db.4.6.community-operators
INDEX_DB_PATH_AND_NAME?=olm_catalog_indexes/index.db.4.7.redhat-operators

# To introduce efficiencies for pulling new images for the Red Hat index,
# we can use the registry.redhat.io v2 api directly. Set these parameters
# if you want to only update when something newer is out there
REGISTRY_REDHAT_IO_USER?=NOTSET
REGISTRY_REDHAT_IO_PASS?=NOTSET

detected_OS := $(shell uname 2>/dev/null || echo Unknown)

.PHONY: all
all: build

.PHONY: build
build:
	go build -o bin/$(PROG_NAME) ./

.PHONY: install
install:
	go install

get-index:
	$(CONTAINER_ENGINE) login registry.redhat.io
ifneq ($(REGISTRY_REDHAT_IO_PASS),NOTSET)
	@# Don't un-@ this next line as it will show the password in the log
	@./get-index.sh $(CONTAINER_ENGINE) ${IMAGE} ${REGISTRY_REDHAT_IO_USER} ${REGISTRY_REDHAT_IO_PASS}
else
	@# If a user doesn't set the password, then let's just force a refresh
	$(CONTAINER_ENGINE) rmi -f $(IMAGE) | true
endif
	$(CONTAINER_ENGINE) run --rm --entrypoint cat $(IMAGE) /database/index.db > \
	$(INDEX_DB_PATH_AND_NAME)

run: build
	sed 's+olm_catalog_indexes/index.db.4.6.redhat-operators+$(INDEX_DB_PATH_AND_NAME)+' sqlite3.sql > sqlite3_exec.sql
	cp $(PWD)/config.json /tmp/config.json
	sqlite3 -bail -init sqlite3_exec.sql 2>/dev/null | bin/$(PROG_NAME) $(ARGS) 1>$(MERMAID_TEMP_SCRIPT)
	cp $(PWD)/$(MERMAID_TEMP_SCRIPT) /tmp/$(MERMAID_TEMP_SCRIPT)
	touch /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)
	chmod o+w /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE)
	$(CONTAINER_ENGINE) pull $(MERMAID_IMAGE)
	$(CONTAINER_ENGINE) run \
		--privileged \
		-v /tmp/$(MERMAID_TEMP_SCRIPT):/$(MERMAID_TEMP_SCRIPT) \
		-v /tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE):/tmp/$(MERMAID_TEMP_SCRIPT).$(OUTPUT_TYPE) \
		-v /tmp/config.json:/config.json \
		-v /tmp:/app/.cache/yarn \
		-it \
		$(MERMAID_IMAGE) \
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

