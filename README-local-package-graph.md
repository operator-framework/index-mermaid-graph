## To make a Mermaid graph for your operator index

### Required:
sed, make, git, container execution environment (such as Docker, podman)

### Usage
```bash
git clone git@github.com:jmccormick2001/sample-operator
cd sample-operator
make bundle-build
docker tag controller-bundle:2.0.0 quay.io/btofel/controller-bundle:v2.0.0
docker push quay.io/btofel/controller-bundle:v2.0.0
opm registry add --bundle-images quay.io/btofel/controller-bundle:v2.0.0 --database "test-registry.db"
cd <index_mermaid_graph_install_repo_dir>
INDEX_DB_PATH_AND_NAME=<path>/<to>/test-registry.db make run
```
