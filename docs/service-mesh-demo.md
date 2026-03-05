# Service Mesh Demo — Istio on AKS

This guide walks through the key Istio capabilities enabled by the AKS Service Mesh addon
using the cloud-native training application.

## Prerequisites

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-cloud-native-training \
  --name aks-training-<suffix> --overwrite-existing

# Verify Istio is running
kubectl get pods -n aks-istio-system

# Deploy the app (production namespace with sidecar injection)
kubectl label namespace cloud-native-app istio.io/rev=asm-1-22
helm upgrade --install training ./helm/cloud-native-app \
  --namespace cloud-native-app --create-namespace \
  --values helm/cloud-native-app/values-azure.yaml \
  --set <...your values...>

# Verify sidecars are injected (2/2 containers per pod)
kubectl get pods -n cloud-native-app
```

Expected output — each pod shows `2/2 READY` (app + envoy sidecar):

```
NAME                                   READY   STATUS    RESTARTS
backend-deployment-xxx                 2/2     Running   0
frontend-deployment-xxx                2/2     Running   0
```

---

## 1. mTLS — Zero-Trust Pod-to-Pod Encryption

Istio automatically enforces mutual TLS between all pods in labelled namespaces.
No application code changes are needed.

### Verify mTLS is active

```bash
# Check PeerAuthentication policy (STRICT mode = no plaintext allowed)
kubectl get peerauthentication -n cloud-native-app

# Inspect the TLS certificate on a running sidecar
kubectl exec -n cloud-native-app \
  $(kubectl get pod -n cloud-native-app -l app=backend -o jsonpath='{.items[0].metadata.name}') \
  -c istio-proxy -- openssl s_client -connect frontend-service:80 -showcerts 2>/dev/null \
  | openssl x509 -noout -text | grep -A2 "Subject:"
```

### Apply STRICT mTLS across the namespace

```yaml
# kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: cloud-native-app
spec:
  mtls:
    mode: STRICT   # Reject all plaintext connections
```

---

## 2. Traffic Management

### 2a. VirtualService — Weighted Traffic Split (Canary Release)

Deploy a `v2` version of the backend alongside `v1` and split traffic 90/10.

```bash
# Tag the current backend as v1
kubectl label deployment backend-deployment version=v1 -n cloud-native-app

# Deploy a canary backend (e.g. new image tag)
kubectl apply -n cloud-native-app -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment-v2
  namespace: cloud-native-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v2
  template:
    metadata:
      labels:
        app: backend
        version: v2
    spec:
      containers:
        - name: backend
          image: <acr>.azurecr.io/backend:<new-tag>
          ports:
            - containerPort: 3000
EOF
```

Create `DestinationRule` and `VirtualService`:

```yaml
# kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend
  namespace: cloud-native-app
spec:
  host: backend-service
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend
  namespace: cloud-native-app
spec:
  hosts:
    - backend-service
  http:
    - route:
        - destination:
            host: backend-service
            subset: v1
          weight: 90
        - destination:
            host: backend-service
            subset: v2
          weight: 10
```

Watch the split:

```bash
# Generate traffic
kubectl exec -n cloud-native-app \
  $(kubectl get pod -n cloud-native-app -l app=frontend -o jsonpath='{.items[0].metadata.name}') \
  -c frontend -- sh -c 'for i in $(seq 1 20); do wget -qO- http://backend-service:3000/api/items; done'

# Gradually shift to 100% v2
kubectl patch virtualservice backend -n cloud-native-app \
  --type=json -p='[{"op":"replace","path":"/spec/http/0/route/0/weight","value":0},
                   {"op":"replace","path":"/spec/http/0/route/1/weight","value":100}]'
```

---

### 2b. Fault Injection — Chaos Testing

Inject a 3-second delay on 50% of requests to the backend to test frontend resilience:

```yaml
# kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-fault
  namespace: cloud-native-app
spec:
  hosts:
    - backend-service
  http:
    - fault:
        delay:
          percentage:
            value: 50
          fixedDelay: 3s
      route:
        - destination:
            host: backend-service
```

Inject HTTP 500 errors on 20% of requests:

```yaml
    - fault:
        abort:
          percentage:
            value: 20
          httpStatus: 500
```

Remove the fault:

```bash
kubectl delete virtualservice backend-fault -n cloud-native-app
```

---

### 2c. Circuit Breaker

Automatically eject unhealthy backend pods from the load-balancing pool:

```yaml
# kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-cb
  namespace: cloud-native-app
spec:
  host: backend-service
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 3        # Eject after 3 consecutive errors
      interval: 10s                  # Scan interval
      baseEjectionTime: 30s          # Minimum ejection duration
      maxEjectionPercent: 50         # Never eject more than 50% of hosts
```

---

## 3. AuthorizationPolicy — Zero-Trust Access Control

Block all traffic by default, then explicitly allow only frontend → backend:

```yaml
# kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: cloud-native-app
spec: {}  # Empty spec = deny everything
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: cloud-native-app
spec:
  selector:
    matchLabels:
      app: backend
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/cloud-native-app/sa/frontend-sa"
      to:
        - operation:
            methods: ["GET", "POST", "DELETE"]
            paths: ["/api/*", "/health", "/metrics"]
```

---

## 4. Observability

### Kiali — Service Mesh Topology

The AKS Istio addon does not bundle Kiali. Install it separately:

```bash
helm repo add kiali https://kiali.org/helm-charts
helm install kiali-server kiali/kiali-server \
  --namespace aks-istio-system \
  --set auth.strategy=anonymous \
  --set external_services.prometheus.url=http://training-prometheus-server.cloud-native-app.svc.cluster.local

# Open dashboard
kubectl port-forward svc/kiali 20001:20001 -n aks-istio-system
# Browse: http://localhost:20001
```

### Distributed Tracing via Jaeger

The training app already exports OTLP traces to Jaeger (deployed by the Helm chart).
Istio's Envoy sidecar propagates trace context automatically (no code changes needed).

```bash
kubectl port-forward svc/jaeger 16686:16686 -n cloud-native-app
# Browse: http://localhost:16686 → select service "backend-api"
```

---

## 5. Ingress Gateway

The AKS Istio addon creates an internal `IstioIngressGateway`. Expose the frontend through it:

```yaml
# kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: training-gateway
  namespace: cloud-native-app
spec:
  selector:
    istio: aks-istio-ingressgateway-internal
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "training.internal"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend-ingress
  namespace: cloud-native-app
spec:
  hosts:
    - "training.internal"
  gateways:
    - training-gateway
  http:
    - route:
        - destination:
            host: frontend-service
            port:
              number: 80
```

Get the internal load balancer IP:

```bash
kubectl get svc aks-istio-ingressgateway-internal \
  -n aks-istio-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## 6. Cleanup

```bash
# Remove individual policies
kubectl delete peerauthentication default -n cloud-native-app
kubectl delete authorizationpolicy deny-all allow-frontend-to-backend -n cloud-native-app
kubectl delete virtualservice backend backend-fault frontend-ingress -n cloud-native-app
kubectl delete destinationrule backend backend-cb -n cloud-native-app
kubectl delete gateway training-gateway -n cloud-native-app

# Remove canary deployment
kubectl delete deployment backend-deployment-v2 -n cloud-native-app
```

---

## Architecture Overview

```
Internet
    │
    ▼
[AKS Istio Ingress Gateway] ──── Gateway / VirtualService
    │
    ▼
[frontend-service]  ← mTLS ←  [backend-service]  ← mTLS ←  [Azure PostgreSQL]
     │                              │
  Envoy sidecar               Envoy sidecar
  (metrics, traces,           (metrics, traces,
   mTLS, auth)                 mTLS, auth)
    │                              │
    └──────────── Telemetry ───────┘
                      │
               [Prometheus] → [Grafana]
               [Jaeger]     → [Grafana]
               [Kiali]      (topology)
```
