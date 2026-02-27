# Kubernetes Demos

This directory contains demos for learning Kubernetes concepts including Pods, ReplicaSets, Deployments, Services, and Ingress Controller using Minikube.

## Prerequisites

- Minikube installed
- kubectl installed
- Docker installed (for building images)

## Setup Minikube

```bash
# Start minikube
minikube start --driver=docker

# Enable ingress addon
minikube addons enable ingress

# Verify minikube is running
minikube status

# Set kubectl context to minikube
kubectl config use-context minikube
```

## Demo 1: Pods

Pods are the smallest deployable units in Kubernetes.

### Deploy a Single Pod

```bash
# Create namespace
kubectl apply -f kubernetes/00-namespace.yaml

# Create the pod
kubectl apply -f kubernetes/01-pod.yaml

# List pods
kubectl get pods -n cloud-native-training

# Describe pod
kubectl describe pod backend-pod -n cloud-native-training

# View pod logs
kubectl logs backend-pod -n cloud-native-training

# Execute command in pod
kubectl exec -it backend-pod -n cloud-native-training -- sh

# Port forward to access the pod
kubectl port-forward backend-pod 3000:3000 -n cloud-native-training

# Delete the pod
kubectl delete pod backend-pod -n cloud-native-training
```

### Pod Lifecycle

```bash
# Watch pod status in real-time
kubectl get pods -n cloud-native-training --watch

# Get pod in YAML format
kubectl get pod backend-pod -n cloud-native-training -o yaml

# Get pod in JSON format
kubectl get pod backend-pod -n cloud-native-training -o json

# Get pod events
kubectl get events -n cloud-native-training --sort-by='.lastTimestamp'
```

## Demo 2: ReplicaSets

ReplicaSets ensure a specified number of pod replicas are running at all times.

### Deploy a ReplicaSet

```bash
# Create the ReplicaSet
kubectl apply -f kubernetes/02-replicaset.yaml

# List ReplicaSets
kubectl get replicaset -n cloud-native-training
kubectl get rs -n cloud-native-training  # short form

# Describe ReplicaSet
kubectl describe rs backend-replicaset -n cloud-native-training

# List pods created by ReplicaSet
kubectl get pods -n cloud-native-training -l app=backend

# Watch pods
kubectl get pods -n cloud-native-training --watch
```

### Scale ReplicaSet

```bash
# Scale to 5 replicas
kubectl scale replicaset backend-replicaset --replicas=5 -n cloud-native-training

# Verify scaling
kubectl get rs backend-replicaset -n cloud-native-training
kubectl get pods -n cloud-native-training -l app=backend

# Scale down to 2 replicas
kubectl scale replicaset backend-replicaset --replicas=2 -n cloud-native-training
```

### Self-Healing Demo

```bash
# Delete a pod
kubectl delete pod <pod-name> -n cloud-native-training

# Watch ReplicaSet create a new pod
kubectl get pods -n cloud-native-training --watch

# Verify the replica count is maintained
kubectl get rs backend-replicaset -n cloud-native-training
```

### Cleanup

```bash
# Delete the ReplicaSet (and its pods)
kubectl delete rs backend-replicaset -n cloud-native-training
```

## Demo 3: Deployments

Deployments provide declarative updates for Pods and ReplicaSets.

### Deploy the Complete Application

```bash
# Deploy all components (database, backend, frontend)
kubectl apply -f kubernetes/03-deployments.yaml

# List all deployments
kubectl get deployments -n cloud-native-training
kubectl get deploy -n cloud-native-training  # short form

# List all pods
kubectl get pods -n cloud-native-training

# Describe a deployment
kubectl describe deployment backend-deployment -n cloud-native-training

# View deployment status
kubectl rollout status deployment backend-deployment -n cloud-native-training
```

### Update a Deployment

```bash
# Update the image version (simulated update)
kubectl set image deployment/backend-deployment backend=tasb/training-backend:v2 -n cloud-native-training

# Watch the rollout
kubectl rollout status deployment backend-deployment -n cloud-native-training

# View rollout history
kubectl rollout history deployment backend-deployment -n cloud-native-training

# Undo a rollout
kubectl rollout undo deployment backend-deployment -n cloud-native-training

# Rollback to a specific revision
kubectl rollout undo deployment backend-deployment --to-revision=1 -n cloud-native-training
```

### Scale a Deployment

```bash
# Scale backend to 5 replicas
kubectl scale deployment backend-deployment --replicas=5 -n cloud-native-training

# Autoscale (requires metrics server)
kubectl apply -f 06-hpa.yaml

# View horizontal pod autoscaler
kubectl get hpa -n cloud-native-training
```

### Working with ConfigMaps and Secrets

```bash
# View ConfigMaps
kubectl get configmaps -n cloud-native-training
kubectl describe configmap postgres-config -n cloud-native-training

# View Secrets (values are base64 encoded)
kubectl get secrets -n cloud-native-training
kubectl describe secret postgres-secret -n cloud-native-training

# Decode secret
kubectl get secret postgres-secret -n cloud-native-training -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

## Demo 4: Services

Services provide stable networking and load balancing for pods.

### Deploy Services

```bash
# Create all services
kubectl apply -f kubernetes/04-services.yaml

# List services
kubectl get services -n cloud-native-training
kubectl get svc -n cloud-native-training  # short form

# Describe a service
kubectl describe svc backend-service -n cloud-native-training

# View service endpoints
kubectl get endpoints -n cloud-native-training
```

### Service Types Demo

#### ClusterIP (Internal Access)

```bash
# ClusterIP is the default - accessible only within the cluster
kubectl get svc postgres-service -n cloud-native-training

# Access from within a pod
kubectl run -it --rm debug --image=alpine --restart=Never -n cloud-native-training -- sh
# Inside pod:
# wget -qO- http://backend-service:3000/health
```

#### NodePort (External Access)

```bash
# NodePort exposes the service on each node's IP at a static port
kubectl get svc backend-nodeport -n cloud-native-training

# Get minikube IP
minikube ip

# Or use minikube service command
minikube service backend-nodeport -n cloud-native-training
minikube service frontend-nodeport -n cloud-native-training
```


### Service Discovery

```bash
# DNS-based service discovery
kubectl run -it --rm debug --image=alpine --restart=Never -n cloud-native-training -- sh

# Inside pod, install curl
apk add curl

# Access services by name
curl http://backend-service:3000/health
curl http://postgres-service:5432

# Full DNS name
curl http://backend-service.cloud-native-training.svc.cluster.local:3000/health
```

## Demo 5: Ingress Controller

Ingress provides HTTP/HTTPS routing to services.

### Enable Ingress in Minikube

```bash
# Enable ingress addon
minikube addons enable ingress

# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Deploy Ingress

```bash
# Create ingress
kubectl apply -f kubernetes/05-ingress.yaml

# List ingress
kubectl get ingress -n cloud-native-training
kubectl get ing -n cloud-native-training  # short form

# Describe ingress
kubectl describe ingress training-ingress -n cloud-native-training

# Get ingress address
kubectl get ingress training-ingress -n cloud-native-training
```

### Configure Local DNS

```bash
# Get minikube IP
minikube ip

# Add to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
echo "$(minikube ip) training.local" | sudo tee -a /etc/hosts
echo "$(minikube ip) frontend.training.local" | sudo tee -a /etc/hosts
echo "$(minikube ip) api.training.local" | sudo tee -a /etc/hosts
```

### Test Ingress

```bash
# Access via ingress
curl http://training.local/
curl http://training.local/api/items

# Access via multi-host ingress
curl http://frontend.training.local/
curl http://api.training.local/health
curl http://api.training.local/api/items

# Open in browser
minikube service frontend-nodeport -n cloud-native-training --url
# Or access via ingress
open http://training.local  # Mac
xdg-open http://training.local  # Linux
```

### Ingress Path-Based Routing

The ingress routes traffic based on paths:
- `/` -> frontend-service
- `/api` -> backend-service

```bash
# Test path-based routing
curl http://training.local/
curl http://training.local/api/health
```

## Demo 6: Horizontal Pod Autoscaler

Horizontal Pod Autoscaler (HPA) automatically scales the number of pods in a deployment based on CPU utilization or other metrics.

### Prerequisites

Ensure Metrics Server is installed in your cluster (required for CPU-based scaling):

```bash
# Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics server is running
kubectl get pods -n kube-system | grep metrics-server

# Wait for metrics to be available
kubectl top nodes
kubectl top pods -n cloud-native-training
```

### Deploy HPA

```bash
# Create HPA for backend deployment
kubectl apply -f kubernetes/06-hpa.yaml

# List HPAs
kubectl get hpa -n cloud-native-training

# Describe HPA
kubectl describe hpa backend-hpa -n cloud-native-training
```

### Test HPA Scaling

To demonstrate HPA, we need to generate CPU load on the backend pods to trigger scaling up.

```bash
# Use the provided script to start/stop load
./kubernetes/hpa-test.sh start
./kubernetes/hpa-test.sh stop

# Or manually start CPU load on each backend pod
kubectl exec -it <backend-pod-name> -n cloud-native-training -- sh -c "dd if=/dev/zero of=/dev/null &"

# Monitor scaling
kubectl get hpa -n cloud-native-training -w
kubectl get pods -n cloud-native-training -l app=backend -w

# Stop the load manually
kubectl exec -it <backend-pod-name> -n cloud-native-training -- sh -c "pkill dd"
```

### HPA Configuration

The HPA is configured to:
- Target: `backend-deployment`
- Min replicas: 1
- Max replicas: 10
- CPU utilization target: 50%

## Complete Application Demo


### Access the Application

```bash
# Via NodePort
minikube service frontend-nodeport -n cloud-native-training

# Via Ingress (after configuring /etc/hosts)
open http://training.local

```


## Cleanup

```bash
# Delete all resources in namespace
kubectl delete namespace cloud-native-training

# Or delete individually
kubectl delete -f kubernetes/05-ingress.yaml
kubectl delete -f kubernetes/04-services.yaml
kubectl delete -f kubernetes/03-deployments.yaml
kubectl delete -f kubernetes/02-replicaset.yaml
kubectl delete -f kubernetes/01-pod.yaml
kubectl delete -f kubernetes/00-namespace.yaml

# Stop minikube
minikube stop

# Delete minikube cluster
minikube delete
```
