# Part 1 - Local Setup

## Docker
Ensure docker has 8+Gb of RAM and 3 to 4 CPUs

## Minishift
Run `start-minishift.sh` and wait until the VM is up.

To check if eveything is fine run `open https://$(minishift ip):8443`
or open the url `echo https://$(minishift ip):8443`. Log in with
admin or developer credentials.

## Istio
Go to the istio installation folder and deploy istio to the cluster:

```
# Apply istio Custom Resource Definitions
kubectl apply -f install/kubernetes/helm/istio/templates/crds.yaml

# Apply istio components
kubectl apply -f install/kubernetes/istio-demo.yaml
```

It will take a while until all images are downloaded and deployed, you
can monitor the progress by going to the istio-system namespace and listing
pods, deployment and services:

```
oc project istio-system
# or kubectl config set-context $(kubectl config current-context) --namespace=istio-system

kubectl get pod,svc,deploy
# Useful commands for debug:
# List all events
# kubectl get events
# Check pod logs
# kubectl logs <pod-id>
# Check pod, deploy or service status
# kubectl describe <pod|svc|deploy> <id>
```

If everything went well you should see all pods in either `Completed`
or `Running` status (specially the `istio-*` pods).

## Accessing the components

If you want to check the logs, or trace requests, remember to first expose
these services:

```
oc expose svc istio-ingressgateway
oc expose svc servicegraph
oc expose svc grafana
oc expose svc prometheus
oc expose svc tracing
```

Now you can get their ip via routes table or via minishift:

```
kubectl get routes
# Will list all endpoints
# Or
minishift openshift service <service-name> --in-browser
```

# Part 2 - Deploying single app

## Helloworld istio sample
Go to istio instalation folder and then into `samples/helloworld`, it
contains a simple helloworld service and a yaml file defining the Deployment,
Pod and Service k8s components.

```
kubectl apply -f helloworld.yaml
```

Now you need to expose the service to outside the container, use
`oc` to create a dns entry for the helloworld Service you just applied.

```
oc expose service helloworld
```

Now to access the service, check k8s route table to find out the dns:

```
kubectl get route
# something like <service-name>-<namespace>.<minishift-vm-ip>.nip.io:<port>
```

If everything went well you should be able to reach the hello world service.

## Demo app
We'll use the yaml descibred in `deployment/deploy-app.yaml` do create
service, deployment and pods for the demoapp.

Create a new Openshift project (or namespace):

```
oc new-project java-demo
# Or
# kubectl create namespace java-demo
# kubectl config set-context $(kubectl config current-context) --namespace=java-demo
```

Set oc permissions for the newly created namespace

```
oc adm policy add-scc-to-user privileged -z default -n java-demo
```

Make sure you've setup the environment variable for minishift:

```
eval $(minishift oc-env)
eval $(minishift docker-env)
```

Now apply the yaml file using `istioctl kube-inject` to inject the sidecars:

```
kubectl apply -f <(istioctl kube-inject -f deployment/deploy-app.yaml) -n java-demo
```

Then wait untill all pods are up and running:

```
watch -n2 kubectl get deploy,pod,svc
```

Once everything is running, expose the service:

```
oc expose service java-demo
```

And finally check the routes table to get the url where the service is accessible

```
kubectl get routes
# Something like java-demo-demoapp.192.168.99.100.nip.io
```

# Part 3 - Deploying 3-tier services

Now we'll be deploying redhat's sample application with 3 services:

Customer -> Preferences -> Recommendation

Download the code from https://github.com/redhat-developer-demos/istio-tutorial

Before moving on, make sure you create a new project via `oc` (which will
also setup a namespace):

```
oc new-project tutorial
```

## Building & deploying costumer service

Build the docker image:

```
cd customer/java/springboot
mvn clean package
docker build -t example/customer .
```

Now apply the Deployment & Pod definitions:

```
kubectl apply -f <(istioctl kube-inject -f ../../kubernetes/Deployment.yml) -n tutorial
```

Once that's done, create a service to expose the pods within the cluster:

```
kubectl apply -f ../../kubernetes/Service.yml
```

And because costumer service will be accessed by the end users, expose it
via `oc expose` so that a DNS is created to access it:

```
oc expose service customer -n tutorial
```

Now, if you go check the routes table, an entry for the customer service,
similar to the helloworld service:

```
kubectl get routes
```

If you try to reach out to the customer endpoint you will see a message
with an error, because the other services are not setup yet.

## Building & deploying preferences service

Build the docker image:

```
cd preference/java/springboot
mvn clean package
docker build -t example/preference:v1 .
```

Then apply the deploy and the service:

```
kubectl apply -f <(istioctl kube-inject -f ../../kubernetes/Deployment.yml) -n tutorial
kubectl apply -f ../../kubernetes/Service.yml
```

Since preference won't be accessed from outside the cluster, we don't
need to expose it.

## Building & deploying recommendation

Again, build the docker image and apply the k8s components:

```
cd recommendation/java/vertx
mvn clean package
docker build -t example/recommendation:v1 .
kubectl apply -f <(istioctl kube-inject -f ../../kubernetes/Deployment.yml) -n tutorial
kubectl apply -f ../../kubernetes/Service.yml
```

Accessing the customer endpoint now should display a message with
all three tiers of services:

```
http http://customer-tutorial.192.168.99.100.nip.io
# should display customer => preference => recommendation v1
```

# Part 4 - Routing between versions

## Recommendations v2
To simulate a deployment, create a new version of recommendation by editing 
the `RESPONSE_STRING_FORMAT` at `RecommendationVerticle.java` to say v2:

```
// private static final String RESPONSE_STRING_FORMAT = "recommendation v1 from '%s': %d\n";
private static final String RESPONSE_STRING_FORMAT = "recommendation v2 from '%s': %d\n";
```

Then, build a v2 image:

```
mvn clean package
docker build -t example/recommendation:v2 .
```

Finally, apply the v2 deployment description, so we have both v1 and v2
pods running:

```
kubectl apply -f <(istioctl kube-inject -f ../../kubernetes/Deployment-v2.yml) -n tutorial
```

Now, if you try to hit the customer endpoint you should see v1 and v2
being displayed:

```
http http://customer-tutorial.192.168.99.100.nip.io
# should display customer => preference => recommendation v1
http http://customer-tutorial.192.168.99.100.nip.io
# should display customer => preference => recommendation v2
```

## Routing - Canary release
Now let's add a rule that would simulate a canary release of v2 by only
sending 10% of the traffic to it. Make sure you are at the root folder of
`istio-tutorial` and first create a destination rule to map both v1 and v2
of recommendation service:

```
istioctl create -f istiofiles/destination-rule-recommendation-v1-v2.yml -n tutorial
```

Then apply the VirtualService component to control how traffic is split
between the two versions:

```
istioctl create -f istiofiles/virtual-service-recommendation-v1_and_v2.yml -n tutorial
```

To simulate load, use the `scripts/run.sh` script which will just curl the
endpoint indefinitely.

*Remember to delete virtual services after you're done!*

```
istioctl delete -f istiofiles/virtual-service-recommendation-v1_and_v2.yml -n tutorial
```

## Routing - Dark launch
Let's now simulate a dark launch of recommendations v2. All traffic will be
going to v1 and we'll mirror it to v2.

```
istioctl create -f istiofiles/virtual-service-recommendation-v1-mirror-v2.yml -n tutorial
```

Now all responses will include only v1, but if we check the logs on v2
we should see it being hit as well:

```
stern recommendation -c recommendation -l version=v2
```
