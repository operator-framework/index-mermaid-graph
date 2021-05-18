## Output Mermaid graph script from Operator Lifecycle Manager indices

### Required:
- make
- sqlite3 
- go v14+ 
- container execution environment (such as Docker, podman)

### Usage
Setting `INDEX_DB_PATH_AND_NAME` controls the file pointed to in `sqlite3.sql`, this controls what index gets graphed.

Without setting `INDEX_DB_PATH_AND_NAME` just using the 4.6 index for Red Hat operators:
```bash
make run <ARGS=operator-package-name>
```
For instance:
```bash
make run ARGS=amq-operator
```
or, to change the index used:
```bash
INDEX_DB_PATH_AND_NAME=olm_catalog_indexes/index.db.4.7.redhat-operators make run ARGS=jaeger-product
```

Your Mermaid graph should open if `open` command opens the chosen graphic output type files (PNG, SVG, etc.) on your host.

If not, image file saved as `/tmp/mermaid.mer.png`<br>
Mermaid script file will be `./mermaid.mer`

### Note
- First time usage of `make run` may be slow due to download of Mermaid Docker image.
- tweak the makefile if you need other file output types than SVG

### Note about index freshening

Turns out, if you're not logged into two Red Hat registries you will silently be redirected to other images for the redhat-redhat indexes
This repo comes with some recent downloads of the indexes that have been pulled after logging into these registries.
You may want to recreate this process with the following command as a template:
```bash
docker login https://registry.connect.redhat.com
docker login registry.redhat.io
docker rmi --force registry.redhat.io/redhat/redhat-operator-index:v4.8
docker run --rm --entrypoint cat registry.redhat.io/redhat/redhat-operator-index:v4.8 /database/index.db > olm_catalog_indexes/index.db.4.8.redhat-operators
```
Running the above would get the true latest index for OpenShift 4.8.