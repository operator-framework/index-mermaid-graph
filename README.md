## Output Mermaid graph script from Operator Lifecycle Manager indices

### Dependencies
#### Required
- make
- sqlite3 
- go v14+ 
- container execution environment (such as Docker, podman)
#### Optional
- jq (needed to intelligently delete current index only if outdated)

### Usage
Setting `INDEX_DB_PATH_AND_NAME` controls the file pointed to in `sqlite3.sql`, this controls what index gets graphed.

#### Get or refresh the index image
You will need to have the index image locally so that you can extract the olm database from it.

As it turns out, if you're not logged into two Red Hat registries you will silently be redirected to other images for the redhat-redhat indexes
This repo comes with some recent downloads of the indexes that have been pulled after logging into these registries.
You may want to recreate this process with the following command as a template:
```bash
docker login https://registry.connect.redhat.com
docker login registry.redhat.io
docker rmi --force registry.redhat.io/redhat/redhat-operator-index:v4.8
docker run --rm --entrypoint cat registry.redhat.io/redhat/redhat-operator-index:v4.8 /database/index.db > olm_catalog_indexes/index.db.4.8.redhat-operators
```
Running the above would get the true latest index for OpenShift 4.8.

If you want to get the latest image yourself, you can use the `get-index` Make target. This will force you to download the latest
index image (and therefore latest database) present.

```bash
INDEX_DB_PATH_AND_NAME=olm_catalog_indexes/index.db.4.7.redhat-operators
IMAGE=registry.redhat.io/redhat/redhat-operator-index:v4.7 
make get-index
```

By default, this will always delete the `IMAGE` from your local system and will therefore always pull an image when run. If, however,
you only want to delete your local image when a newer image is available for pulling you can set/pass credentials for `registry.redhat.io`.

```bash
make get-index REGISTRY_REDHAT_IO_USER=<username> REGISTRY_REDHAT_IO_PASS=<password> CONTAINER_ENGINE=podman 
```

#### Generating the graph
Without setting `INDEX_DB_PATH_AND_NAME` just using the 4.7 index for Red Hat operators:
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

If you are using `podman` instead of `docker` CLI, you can still leverage this script by exporting `CONTAINER_ENGINE`
```bash
export CONTAINER_ENGINE=podman
```
or just adding it to the parameters for each run:
```bash
CONTAINER_ENGINE=podman INDEX_DB_PATH_AND_NAME=olm_catalog_indexes/index.db.4.7.redhat-operators make run ARGS=jaeger-product
```

### Note
- First time usage of `make run` may be slow due to download of Mermaid Docker image.
- tweak the makefile if you need other file output types than SVG
- `podman` on OSX will not work by default as there is not native support for mounting volumes on the client host. A potential workaround can be found in [this issue](https://github.com/containers/podman/issues/8016#issuecomment-920015800)