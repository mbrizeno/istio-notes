#!/bin/bash

# Redhat tutorial: https://github.com/redhat-developer-demos/istio-tutorial

# Start cluster with enough mem & cpu
minishift profile set oc-istio-demo
minishift config set memory 10GB
minishift config set cpus 4
minishift config set vm-driver virtualbox
minishift config set image-caching true
minishift config set openshift-version v3.10.0
minishift addon enable admin-user
minishift addon enable anyuid
minishift start

# Setup env vars (has to run on each terminal you plan on acessing minishift)
eval $(minishift oc-env)
eval $(minishift docker-env)

# Log in to the cluster
# Admin credentials
oc login $(minishift ip):8443 -u admin -p admin
# Developer credentials
# oc login $(minishift ip):8443 -u developer -p developer

# Setup oc policies for istio and add-ons
# More on https://blog.openshift.com/understanding-service-accounts-sccs/
oc new-project istio-system
oc adm policy add-scc-to-user anyuid -z istio-ingress-service-account
oc adm policy add-scc-to-user privileged -z istio-ingress-service-account
oc adm policy add-scc-to-user anyuid -z istio-egress-service-account
oc adm policy add-scc-to-user privileged -z istio-egress-service-account
oc adm policy add-scc-to-user anyuid -z istio-pilot-service-account
oc adm policy add-scc-to-user privileged -z istio-pilot-service-account
oc adm policy add-scc-to-user anyuid -z istio-grafana-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-prometheus-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z prometheus -n istio-system
oc adm policy add-scc-to-user privileged -z prometheus
oc adm policy add-scc-to-user anyuid -z grafana -n istio-system
oc adm policy add-scc-to-user privileged -z grafana
oc adm policy add-scc-to-user anyuid -z default
oc adm policy add-scc-to-user privileged -z default
oc adm policy add-cluster-role-to-user cluster-admin -z default
