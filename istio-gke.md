# Setup

Run all commands from the istio source folder.

Make sure you have setup `gcloud` with your credentials. Run 
`gcloud init` to setup a project, zone and other required things.

1. Create cluster

```
gcloud container clusters create istio-on-gke \
 --cluster-version=latest \
 --zone us-central1-a \
 --num-nodes 4
```

1. Log in to the cluster

```
gcloud container clusters get-credentials istio-on-gke
```

1. Create a `clusterrolebinding`

```
kubectl create clusterrolebinding cluster-admin-binding \
 --clusterrole=cluster-admin \
 --user=$(gcloud config get-value core/account)
```

1. Apply istio components

```
kubectl apply -f install/kubernetes/istio-demo.yaml
```

1. Apply bookinfo components

```
# Deploy all components
kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/platform/kube/bookinfo.yaml)
# Create a gateway to access them
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

1. Export some env vars to make it easy to access the service

```
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
```

Now open the service by using the `INGRESS_HOST` and `INGRESS_PORT`:

```
echo http://${INGRESS_HOST}:${INGRESS_PORT}/productdetail
```

1. To access the services installed with istio create a proxy with `kubectl`

```
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=<app-name> -o jsonpath='{.items[0].metadata.name}') <port>:<port>
# for example, Jaeger
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}') 16686:16686
```
