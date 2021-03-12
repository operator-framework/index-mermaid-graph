## To make a Mermaid graph for your operator

### Required:
olm, jq, grpcurl, container execution environment (such as Docker, podman)

### Usage
```bash
git clone git@github.com:jmccormick2001/sample-operator
make bundle-build
docker tag controller-bundle:2.0.0 quay.io/btofel/controller-bundle:v2.0.0
docker push quay.io/btofel/controller-bundle:v2.0.0
opm index add --bundles quay.io/btofel/controller-bundle:v2.0.0 --tag controller-bundle-index:v2.0.0 --build-tool docker
docker run -d -p 50051:50051 controller-bundle-index:v2.0.0
grpcurl --plaintext localhost:50051 api.Registry/ListBundles | jq -c '{packageName,csvName,channelName}
```
