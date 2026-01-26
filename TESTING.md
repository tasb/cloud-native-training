# Testing Guide

This guide helps you verify that the cloud native training environment is working correctly.

## Pre-flight Checks

### Docker Environment

```bash
# Verify Docker is running
docker --version
docker info

# Verify Docker Compose
docker compose version

# Test Docker with hello-world
docker run hello-world
```

### Kubernetes Environment

```bash
# Verify kubectl
kubectl version --client

# Verify Minikube
minikube version

# Check if Minikube is running
minikube status
```

## Testing Docker Setup

### Step 1: Build Individual Images

```bash
# Build backend
cd app/backend
docker build -t training-backend:latest .

# Build frontend
cd ../frontend
docker build -t training-frontend:latest .

# Verify images
docker images | grep training
```

### Step 2: Test with Docker Compose

```bash
# Return to root directory
cd /path/to/cloud-native-training

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs

# Test backend
curl http://localhost:3000/health

# Test frontend (in browser)
# Visit: http://localhost:8080
```

### Step 3: Verify Database Connectivity

```bash
# Check database logs
docker compose logs database

# Connect to database
docker exec -it training-db psql -U postgres -d cloudnative

# Inside psql:
\dt
SELECT * FROM items;
\q
```

### Step 4: Test the Full Application

1. Open browser to http://localhost:8080
2. Verify you see the "Cloud Native Training App" interface
3. Add a new item using the form
4. Verify it appears in the list
5. Delete an item
6. Verify it's removed

### Step 5: Cleanup

```bash
# Stop services
docker compose down

# Remove volumes
docker compose down -v
```

## Testing Kubernetes Setup

### Step 1: Start Minikube

```bash
# Start Minikube
minikube start --driver=docker

# Enable ingress
minikube addons enable ingress

# Verify cluster
kubectl cluster-info
```

### Step 2: Build Images in Minikube

```bash
# Point Docker to Minikube
eval $(minikube docker-env)

# Build images
docker build -t training-backend:latest ./app/backend
docker build -t training-frontend:latest ./app/frontend

# Verify images
docker images | grep training
```

### Step 3: Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f kubernetes/00-namespace.yaml

# Deploy application
kubectl apply -f kubernetes/03-deployments.yaml
kubectl apply -f kubernetes/04-services.yaml

# Check deployment
kubectl get all -n cloud-native-training

# Wait for pods
kubectl wait --for=condition=ready pod --all -n cloud-native-training --timeout=300s
```

### Step 4: Test Services

```bash
# Get Minikube IP
minikube ip

# Test backend via NodePort
curl http://$(minikube ip):30000/health

# Test frontend via NodePort
curl http://$(minikube ip):30080

# Or use minikube service
minikube service frontend-nodeport -n cloud-native-training --url
minikube service backend-nodeport -n cloud-native-training --url
```

### Step 5: Test Ingress

```bash
# Apply ingress
kubectl apply -f kubernetes/05-ingress.yaml

# Check ingress
kubectl get ingress -n cloud-native-training

# Add to /etc/hosts
echo "$(minikube ip) training.local" | sudo tee -a /etc/hosts

# Test ingress
curl http://training.local/
curl http://training.local/api/items
```

### Step 6: Verify the Application

1. Open browser to ingress URL or use minikube service
2. Verify you can add, view, and delete items
3. Check all services are communicating

### Step 7: Cleanup

```bash
# Delete namespace
kubectl delete namespace cloud-native-training

# Stop Minikube
minikube stop

# Or delete cluster
minikube delete
```

## Common Issues and Solutions

### Docker Issues

**Issue: Port already in use**
```bash
# Find process using port
lsof -i :3000
lsof -i :8080
lsof -i :5432

# Kill the process or stop other containers
docker compose down
```

**Issue: Image build fails**
```bash
# Check Dockerfile syntax
docker build --no-cache -t training-backend:latest ./app/backend

# View build logs
docker build -t training-backend:latest ./app/backend 2>&1 | tee build.log
```

**Issue: Database not initializing**
```bash
# Remove volumes and restart
docker compose down -v
docker compose up -d

# Check database logs
docker compose logs database
```

### Kubernetes Issues

**Issue: Pods not starting**
```bash
# Describe pod to see events
kubectl describe pod <pod-name> -n cloud-native-training

# Check logs
kubectl logs <pod-name> -n cloud-native-training

# Check events
kubectl get events -n cloud-native-training --sort-by='.lastTimestamp'
```

**Issue: ImagePullBackOff error**
```bash
# This usually means the image isn't in Minikube's registry
# Rebuild images with Minikube's Docker daemon
eval $(minikube docker-env)
docker build -t training-backend:latest ./app/backend
docker build -t training-frontend:latest ./app/frontend

# Verify imagePullPolicy is set to Never in manifests
grep imagePullPolicy kubernetes/*.yaml
```

**Issue: Service not accessible**
```bash
# Check service endpoints
kubectl get endpoints -n cloud-native-training

# Check pod labels match service selector
kubectl get pods -n cloud-native-training --show-labels
kubectl describe service <service-name> -n cloud-native-training
```

**Issue: Ingress not working**
```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress training-ingress -n cloud-native-training

# Verify /etc/hosts entry
cat /etc/hosts | grep training.local
```

## Success Criteria

### Docker Success Criteria

- ✅ All three containers (frontend, backend, database) are running
- ✅ Frontend accessible at http://localhost:8080
- ✅ Backend API responds at http://localhost:3000/health
- ✅ Can add, view, and delete items through the UI
- ✅ Data persists across container restarts
- ✅ Logs show no errors

### Kubernetes Success Criteria

- ✅ All pods are in Running state
- ✅ All pods pass readiness checks
- ✅ Services have endpoints
- ✅ NodePort services accessible from outside cluster
- ✅ Can add, view, and delete items through the UI
- ✅ Rolling updates work without downtime
- ✅ Self-healing: deleted pods are recreated
- ✅ Ingress routes traffic correctly

## Performance Testing (Optional)

### Load Testing Backend

```bash
# Install Apache Bench (if not installed)
apt-get install apache2-utils

# Test backend API
ab -n 1000 -c 10 http://localhost:3000/health
ab -n 100 -c 5 http://localhost:3000/api/items

# For Kubernetes
ab -n 1000 -c 10 http://$(minikube ip):30000/health
```

### Monitoring

```bash
# Docker
docker stats

# Kubernetes
kubectl top pods -n cloud-native-training
kubectl top nodes
```

## Verification Checklist

Use this checklist to verify your setup:

### Docker Verification
- [ ] Docker is installed and running
- [ ] Docker Compose is available
- [ ] Backend image builds successfully
- [ ] Frontend image builds successfully
- [ ] All services start with `docker compose up -d`
- [ ] Database initializes with sample data
- [ ] Frontend accessible in browser
- [ ] Backend API responds to health check
- [ ] Can create items via UI
- [ ] Can delete items via UI
- [ ] Services can be stopped and restarted
- [ ] Data persists when using volumes

### Kubernetes Verification
- [ ] Minikube is installed
- [ ] kubectl is installed
- [ ] Minikube starts successfully
- [ ] Ingress addon is enabled
- [ ] Images build in Minikube environment
- [ ] Namespace created successfully
- [ ] All pods reach Running state
- [ ] All deployments are ready
- [ ] Services have endpoints
- [ ] Frontend accessible via NodePort
- [ ] Backend accessible via NodePort
- [ ] Ingress controller is running
- [ ] Ingress routes work correctly
- [ ] Application functions end-to-end
- [ ] Scaling works (e.g., `kubectl scale`)
- [ ] Rolling updates work
- [ ] Pods self-heal when deleted
